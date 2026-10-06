/* isim host: game controllers on the host (SDL3 gamepad API), polled by the GameController framework's
 * GCController. SDL's gamepad database maps Xbox / PlayStation / Switch / generic pads to one layout.
 * ISIM_GAMEPADS=0 disables host pads. Tests use the `gamepad` script command, which attaches an SDL virtual
 * joystick: it goes through the same SDL gamepad path as a physical pad.
 *   gamepad connect [NAME]           attach a virtual pad (default name "isim Virtual Gamepad")
 *   gamepad button NAME 0|1          a b x y back guide start leftstick rightstick leftshoulder rightshoulder dpup ...
 *   gamepad axis NAME VALUE          leftx lefty rightx righty (-1...1, y down like SDL), lefttrigger righttrigger (0...1)
 *   gamepad disconnect               detach it
 * Rumble requests to the virtual pad are logged ("isim gamepad: rumble LOW HIGH"). */
#include <SDL3/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

struct isim_gamepad { int id, vendor, product; unsigned int buttons; float axes[6]; char name[64]; char type[24]; };

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
int isim_gamepad_poll(struct isim_gamepad *out, int max) {
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
        for (int b = 0; b < SDL_GAMEPAD_BUTTON_MISC1 && b < 32; b++) if (SDL_GetGamepadButton(g, (SDL_GamepadButton)b)) p->buttons |= 1u << b;
        for (int a = 0; a < 6; a++) p->axes[a] = axis(g, (SDL_GamepadAxis)a);
    }
    SDL_free(ids);
    return count;
}

/* rumble (0...1 low / high frequency motors) for `seconds`; 1 if the pad accepted it */
int isim_gamepad_rumble(int id, double low, double high, double seconds) {
    for (int i = 0; i < nopen; i++) if ((int)open_pads[i].id == id) {
        Uint16 lo = (Uint16)(fmin(1, fmax(0, low)) * 65535), hi = (Uint16)(fmin(1, fmax(0, high)) * 65535);
        return SDL_RumbleGamepad(open_pads[i].pad, lo, hi, (Uint32)(fmax(0, seconds) * 1000)) ? 1 : 0;
    }
    return 0;
}

/* ---- script hook: a virtual SDL joystick of gamepad type ---- */
static SDL_JoystickID vid;
static SDL_Joystick *vjoy;
static char vname[64];

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
        snprintf(vname, sizeof vname, "%s", name);
        SDL_VirtualJoystickDesc d;
        SDL_INIT_INTERFACE(&d);
        d.type = SDL_JOYSTICK_TYPE_GAMEPAD;
        d.vendor_id = 0x1209; d.product_id = 0x0001;          /* pid.codes test VID/PID */
        d.nbuttons = SDL_GAMEPAD_BUTTON_MISC1; d.button_mask = (1u << SDL_GAMEPAD_BUTTON_MISC1) - 1;
        d.naxes = SDL_GAMEPAD_AXIS_COUNT; d.axis_mask = (1u << SDL_GAMEPAD_AXIS_COUNT) - 1;
        d.name = vname;
        d.Rumble = v_rumble;
        vid = SDL_AttachVirtualJoystick(&d);
        if (!vid || !(vjoy = SDL_OpenJoystick(vid))) { fprintf(stderr, "isim host: gamepad connect failed: %s\n", SDL_GetError()); return; }
        /* triggers rest at 0 (the virtual axis starts at the middle of its range) */
        SDL_SetJoystickVirtualAxis(vjoy, SDL_GAMEPAD_AXIS_LEFT_TRIGGER, -32768);
        SDL_SetJoystickVirtualAxis(vjoy, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER, -32768);
        fprintf(stderr, "isim host: virtual gamepad '%s' connected\n", vname);
    } else if (!strcmp(verb, "disconnect")) {
        if (!vjoy) return;
        SDL_CloseJoystick(vjoy); vjoy = NULL;
        SDL_DetachVirtualJoystick(vid); vid = 0;
    } else if (!strcmp(verb, "button") && sscanf(args, " %*s %63s %lf", name, &v) == 2) {
        SDL_GamepadButton b = SDL_GetGamepadButtonFromString(name);
        if (!vjoy || b == SDL_GAMEPAD_BUTTON_INVALID || b >= SDL_GAMEPAD_BUTTON_MISC1) { fprintf(stderr, "isim host: gamepad: bad button '%s'\n", name); return; }
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
