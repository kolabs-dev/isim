/* isim host: game controllers on the host (SDL3 gamepad API), polled by the GameController framework's
 * GCController. SDL's gamepad database maps Xbox / PlayStation / Switch / generic pads to one layout.
 * ISIM_GAMEPADS=0 disables host pads. Tests use the `gamepad` script command, which attaches an SDL virtual
 * joystick: it goes through the same SDL gamepad path as a physical pad.
 *   gamepad connect [NAME]           attach a virtual pad (default name "isim Virtual Gamepad")
 *   gamepad button NAME 0|1          a b x y back guide start leftstick rightstick leftshoulder rightshoulder dpup ...
 *   gamepad axis NAME VALUE          leftx lefty rightx righty (-1...1, y down like SDL), lefttrigger righttrigger (0...1)
 *   gamepad disconnect               detach it
 *   gamepad battery PERCENT [discharging|charging|full|unknown]   the virtual pad's battery (SDL has no setter)
 *   gamepad motion AX AY AZ GX GY GZ  accelerometer (m/s², SDL's axes) and gyroscope (rad/s) samples
 *   gamepad connect NAME as ps5|ps4|xbox|switchpro   a virtual pad with that pad's vendor / product (its SDL type)
 *   gamepad touch FINGER 0|1 X Y     the virtual pad's touchpad (x, y in 0...1, y down)
 * Buttons include misc1 (share), paddle1...paddle4 and touchpad. Effect reports (DualSense triggers) are logged as
 * "isim gamepad: effect XX ...".
 * Rumble requests to the virtual pad are logged ("isim gamepad: rumble LOW HIGH"), so are its light colour
 * ("isim gamepad: led R G B") and sensor switches ("isim gamepad: sensors on|off"). */
#include "guest_abi.h"
#include <SDL3/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* buttons: SDL's gamepad button bits (south, east, west, north, back, guide, start, sticks, shoulders, d-pad,
 * misc1 / share, the four paddles, the touchpad button); touch: the first touchpad's two fingers (down, x, y in 0...1) */
struct isim_gamepad { int id, vendor, product; unsigned int buttons; float axes[6]; char name[64]; char type[24];
                      int touchpads; float touch[2][3]; unsigned int has_buttons; };

static int gp_state;                      /* 0 not tried, 1 running, -1 disabled / unavailable */
static struct { SDL_JoystickID id; SDL_Gamepad *pad; } open_pads[16];
static int nopen;

static int gp_init(void) {
    if (gp_state) return gp_state > 0;
    const char *e = getenv("ISIM_GAMEPADS");
    if (e && !strcmp(e, "0")) { gp_state = -1; return 0; }
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    if (!SDL_InitSubSystem(SDL_INIT_GAMEPAD)) {
        fprintf(stderr, "isim host: no gamepad support: %s\n", SDL_GetError());
        gp_state = -1; return 0;
    }
    /* state is read by polling (SDL_UpdateGamepads); no events pile up in queues nobody drains */
    SDL_SetGamepadEventsEnabled(false);
    SDL_SetJoystickEventsEnabled(false);
    gp_state = 1;
    return 1;
}

static float axis(SDL_Gamepad *g, SDL_GamepadAxis a) {
    int v = SDL_GetGamepadAxis(g, a);
    float f = v < 0 ? v / 32768.0f : v / 32767.0f;
    return f;
}

/* fills up to `max` connected pads; returns the count, or -1 when host gamepads are disabled */
ISIM_GUEST_ABI int isim_gamepad_poll(struct isim_gamepad *out, int max) {
    if (!gp_init()) return -1;
    SDL_UpdateGamepads();
    int n = 0;
    SDL_JoystickID *ids = SDL_GetGamepads(&n);
    /* close pads that went away */
    for (int i = 0; i < nopen; ) {
        int found = 0;
        for (int k = 0; k < n; k++) if (ids[k] == open_pads[i].id) found = 1;
        if (!found || !SDL_GamepadConnected(open_pads[i].pad)) {
            SDL_CloseGamepad(open_pads[i].pad);
            open_pads[i] = open_pads[--nopen];
        } else i++;
    }
    int count = 0;
    for (int k = 0; k < n && count < max; k++) {
        SDL_Gamepad *g = NULL;
        for (int i = 0; i < nopen; i++) if (open_pads[i].id == ids[k]) g = open_pads[i].pad;
        if (!g) {
            if (nopen >= 16 || !(g = SDL_OpenGamepad(ids[k]))) continue;
            open_pads[nopen].id = ids[k]; open_pads[nopen].pad = g; nopen++;
        }
        struct isim_gamepad *p = &out[count++];
        memset(p, 0, sizeof *p);
        p->id = (int)ids[k];
        p->vendor = SDL_GetGamepadVendor(g); p->product = SDL_GetGamepadProduct(g);
        snprintf(p->name, sizeof p->name, "%s", SDL_GetGamepadName(g) ? SDL_GetGamepadName(g) : "Gamepad");
        const char *t = SDL_GetGamepadStringForType(SDL_GetGamepadType(g));
        snprintf(p->type, sizeof p->type, "%s", t ? t : "");
        for (int b = 0; b < SDL_GAMEPAD_BUTTON_COUNT && b < 32; b++) if (SDL_GetGamepadButton(g, (SDL_GamepadButton)b)) p->buttons |= 1u << b;
        for (int b = 0; b < SDL_GAMEPAD_BUTTON_COUNT && b < 32; b++) if (SDL_GamepadHasButton(g, (SDL_GamepadButton)b)) p->has_buttons |= 1u << b;
        p->touchpads = SDL_GetNumGamepadTouchpads(g);
        for (int f = 0; f < 2 && p->touchpads > 0; f++) {
            bool down = false; float x = 0, y = 0, pr = 0;
            if (SDL_GetGamepadTouchpadFinger(g, 0, f, &down, &x, &y, &pr)) { p->touch[f][0] = down; p->touch[f][1] = x; p->touch[f][2] = y; }
        }
        for (int a = 0; a < 6; a++) p->axes[a] = axis(g, (SDL_GamepadAxis)a);
    }
    SDL_free(ids);
    return count;
}

/* rumble (0...1 low / high frequency motors) for `seconds`; 1 if the pad accepted it */
ISIM_GUEST_ABI int isim_gamepad_rumble(int id, double low, double high, double seconds) {
    for (int i = 0; i < nopen; i++) if ((int)open_pads[i].id == id) {
        Uint16 lo = (Uint16)(fmin(1, fmax(0, low)) * 65535), hi = (Uint16)(fmin(1, fmax(0, high)) * 65535);
        return SDL_RumbleGamepad(open_pads[i].pad, lo, hi, (Uint32)(fmax(0, seconds) * 1000)) ? 1 : 0;
    }
    return 0;
}

/* a raw effect report for the pad (DualSense adaptive triggers, DualShock 4 lights): SDL's SDL_SendGamepadEffect */
ISIM_GUEST_ABI int isim_gamepad_effect(int id, const void *data, int size) {
    for (int i = 0; i < nopen; i++) if ((int)open_pads[i].id == id) return SDL_SendGamepadEffect(open_pads[i].pad, data, size) ? 1 : 0;
    return 0;
}

/* ---- script hook: a virtual SDL joystick of gamepad type ---- */
static SDL_JoystickID vid;
static SDL_Joystick *vjoy;
static char vname[64];
static int vbattery_state = -2, vbattery_percent = -1;    /* -2: not set by a script */

static SDL_Gamepad *pad_for(int id) {
    for (int i = 0; i < nopen; i++) if ((int)open_pads[i].id == id) return open_pads[i].pad;
    return NULL;
}
/* battery: 0 unknown, 1 discharging, 2 charging, 3 full, -1 none (wired); *percent 0...100 or -1 */
ISIM_GUEST_ABI int isim_gamepad_battery(int id, int *percent) {
    if (percent) *percent = -1;
    if (vjoy && id == (int)vid && vbattery_state != -2) { if (percent) *percent = vbattery_percent; return vbattery_state; }
    SDL_Gamepad *g = pad_for(id);
    if (!g) return 0;
    int pct = -1;
    SDL_PowerState st = SDL_GetGamepadPowerInfo(g, &pct);
    if (percent) *percent = pct;
    switch (st) {
    case SDL_POWERSTATE_ON_BATTERY: return 1;
    case SDL_POWERSTATE_CHARGING: return 2;
    case SDL_POWERSTATE_CHARGED: return 3;
    case SDL_POWERSTATE_NO_BATTERY: return -1;
    default: return 0;
    }
}
/* the pad's light bar (0...1 per channel); 1 if the pad has one */
ISIM_GUEST_ABI int isim_gamepad_set_light(int id, double r, double g, double b) {
    SDL_Gamepad *p = pad_for(id);
    if (!p) return 0;
    Uint8 R = (Uint8)lround(fmin(1, fmax(0, r)) * 255), G = (Uint8)lround(fmin(1, fmax(0, g)) * 255), B = (Uint8)lround(fmin(1, fmax(0, b)) * 255);
    return SDL_SetGamepadLED(p, R, G, B) ? 1 : 0;
}
/* motion sensors: enable 1 / 0 switches them (-1 leaves them); fills the latest accelerometer (m/s²) and gyroscope
 * (rad/s) values; returns 1 (accelerometer) | 2 (gyroscope) for the sensors the pad has */
ISIM_GUEST_ABI int isim_gamepad_motion(int id, int enable, float *accel, float *gyro) {
    SDL_Gamepad *p = pad_for(id);
    if (!p) return 0;
    int has = (SDL_GamepadHasSensor(p, SDL_SENSOR_ACCEL) ? 1 : 0) | (SDL_GamepadHasSensor(p, SDL_SENSOR_GYRO) ? 2 : 0);
    if (enable >= 0) {
        if (has & 1) SDL_SetGamepadSensorEnabled(p, SDL_SENSOR_ACCEL, enable != 0);
        if (has & 2) SDL_SetGamepadSensorEnabled(p, SDL_SENSOR_GYRO, enable != 0);
    }
    if (accel) { memset(accel, 0, 3 * sizeof *accel); if (has & 1) SDL_GetGamepadSensorData(p, SDL_SENSOR_ACCEL, accel, 3); }
    if (gyro) { memset(gyro, 0, 3 * sizeof *gyro); if (has & 2) SDL_GetGamepadSensorData(p, SDL_SENSOR_GYRO, gyro, 3); }
    return has;
}

static bool SDLCALL v_led(void *ud, Uint8 r, Uint8 g, Uint8 b) {
    (void)ud;
    fprintf(stderr, "isim gamepad: led %u %u %u\n", r, g, b);
    return true;
}
static bool SDLCALL v_effect(void *ud, const void *data, int size) {
    (void)ud;
    const unsigned char *b = data;
    fprintf(stderr, "isim gamepad: effect");
    for (int i = 0; i < size && i < 48; i++) fprintf(stderr, " %02x", b[i]);
    fprintf(stderr, "\n");
    return true;
}
static bool SDLCALL v_sensors(void *ud, bool on) {
    (void)ud;
    fprintf(stderr, "isim gamepad: sensors %s\n", on ? "on" : "off");
    return true;
}

static bool SDLCALL v_rumble(void *ud, Uint16 lo, Uint16 hi) {
    (void)ud;
    fprintf(stderr, "isim gamepad: rumble %.2f %.2f\n", lo / 65535.0, hi / 65535.0);
    return true;
}

void isim_gamepad_script(const char *args) {
    char verb[16] = {0}, name[64] = {0}; double v = 0;
    if (sscanf(args, " %15s", verb) != 1) return;
    if (!gp_init()) { fprintf(stderr, "isim host: gamepad: host gamepads are disabled\n"); return; }
    if (!strcmp(verb, "connect")) {
        if (vjoy) return;
        if (sscanf(args, " %*s %63[^;]", name) != 1) snprintf(name, sizeof name, "isim Virtual Gamepad");
        for (char *e = name + strlen(name) - 1; e >= name && *e == ' '; e--) *e = 0;
        /* "NAME as ps5|ps4|xbox|switchpro": the vendor and product of that pad, so SDL (and GameController) see its type */
        Uint16 vendor = 0x1209, product = 0x0001;                 /* pid.codes test VID/PID */
        char *as = strstr(name, " as ");
        if (as) {
            const char *t = as + 4;
            if (!strcmp(t, "ps5")) { vendor = 0x054C; product = 0x0CE6; }
            else if (!strcmp(t, "ps4")) { vendor = 0x054C; product = 0x09CC; }
            else if (!strcmp(t, "xbox")) { vendor = 0x045E; product = 0x0B12; }
            else if (!strcmp(t, "switchpro")) { vendor = 0x057E; product = 0x2009; }
            *as = 0;
        }
        snprintf(vname, sizeof vname, "%s", name);
        SDL_VirtualJoystickDesc d;
        SDL_INIT_INTERFACE(&d);
        d.type = SDL_JOYSTICK_TYPE_GAMEPAD;
        d.vendor_id = vendor; d.product_id = product;
        d.nbuttons = SDL_GAMEPAD_BUTTON_MISC2; d.button_mask = (1u << SDL_GAMEPAD_BUTTON_MISC2) - 1;   /* up to the touchpad button */
        d.naxes = SDL_GAMEPAD_AXIS_COUNT; d.axis_mask = (1u << SDL_GAMEPAD_AXIS_COUNT) - 1;
        d.name = vname;
        d.Rumble = v_rumble;
        d.SetLED = v_led;
        d.SetSensorsEnabled = v_sensors;
        static const SDL_VirtualJoystickSensorDesc sensors[2] = { { SDL_SENSOR_ACCEL, 100.0f }, { SDL_SENSOR_GYRO, 100.0f } };
        d.nsensors = 2; d.sensors = sensors;
        static const SDL_VirtualJoystickTouchpadDesc touchpads[1] = { { 2, { 0, 0, 0 } } };
        d.ntouchpads = 1; d.touchpads = touchpads;
        d.SendEffect = v_effect;
        vid = SDL_AttachVirtualJoystick(&d);
        if (!vid || !(vjoy = SDL_OpenJoystick(vid))) { fprintf(stderr, "isim host: gamepad connect failed: %s\n", SDL_GetError()); return; }
        /* triggers rest at 0 (the virtual axis starts at the middle of its range) */
        SDL_SetJoystickVirtualAxis(vjoy, SDL_GAMEPAD_AXIS_LEFT_TRIGGER, -32768);
        SDL_SetJoystickVirtualAxis(vjoy, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER, -32768);
        fprintf(stderr, "isim host: virtual gamepad '%s' connected\n", vname);
    } else if (!strcmp(verb, "battery") && sscanf(args, " %*s %lf %63s", &v, name) >= 1) {
        vbattery_percent = (int)fmin(100, fmax(0, v));
        vbattery_state = !strcmp(name, "charging") ? 2 : !strcmp(name, "full") ? 3 : !strcmp(name, "unknown") ? 0 : 1;
    } else if (!strcmp(verb, "touch")) {                       /* gamepad touch FINGER 0|1 X Y (0...1, y down) */
        int finger = 0; double down = 0, x = 0, y = 0;
        if (!vjoy || sscanf(args, " %*s %d %lf %lf %lf", &finger, &down, &x, &y) != 4) {
            fprintf(stderr, "isim host: gamepad touch FINGER 0|1 X Y (needs a connected virtual pad)\n"); return;
        }
        SDL_SetJoystickVirtualTouchpad(vjoy, 0, finger, down != 0, (float)x, (float)y, down != 0 ? 1.0f : 0.0f);
    } else if (!strcmp(verb, "motion")) {
        float a[3] = {0}, g[3] = {0};
        if (!vjoy || sscanf(args, " %*s %f %f %f %f %f %f", &a[0], &a[1], &a[2], &g[0], &g[1], &g[2]) != 6) {
            fprintf(stderr, "isim host: gamepad motion AX AY AZ GX GY GZ (needs a connected virtual pad)\n"); return;
        }
        Uint64 t = SDL_GetTicksNS();
        SDL_SendJoystickVirtualSensorData(vjoy, SDL_SENSOR_ACCEL, t, a, 3);
        SDL_SendJoystickVirtualSensorData(vjoy, SDL_SENSOR_GYRO, t, g, 3);
    } else if (!strcmp(verb, "disconnect")) {
        vbattery_state = -2; vbattery_percent = -1;
        if (!vjoy) return;
        SDL_CloseJoystick(vjoy); vjoy = NULL;
        SDL_DetachVirtualJoystick(vid); vid = 0;
    } else if (!strcmp(verb, "button") && sscanf(args, " %*s %63s %lf", name, &v) == 2) {
        SDL_GamepadButton b = SDL_GetGamepadButtonFromString(name);
        if (!vjoy || b == SDL_GAMEPAD_BUTTON_INVALID || b >= SDL_GAMEPAD_BUTTON_MISC2) { fprintf(stderr, "isim host: gamepad: bad button '%s'\n", name); return; }
        SDL_SetJoystickVirtualButton(vjoy, (int)b, v != 0);
    } else if (!strcmp(verb, "axis") && sscanf(args, " %*s %63s %lf", name, &v) == 2) {
        SDL_GamepadAxis a = SDL_GetGamepadAxisFromString(name);
        if (!vjoy || a == SDL_GAMEPAD_AXIS_INVALID) { fprintf(stderr, "isim host: gamepad: bad axis '%s'\n", name); return; }
        int raw;
        if (a == SDL_GAMEPAD_AXIS_LEFT_TRIGGER || a == SDL_GAMEPAD_AXIS_RIGHT_TRIGGER) raw = (int)(fmin(1, fmax(0, v)) * 65535) - 32768;
        else raw = (int)(fmin(1, fmax(-1, v)) * 32767);
        SDL_SetJoystickVirtualAxis(vjoy, (int)a, (Sint16)raw);
    } else fprintf(stderr, "isim host: bad gamepad command '%s'\n", args);
}
