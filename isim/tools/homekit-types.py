#!/usr/bin/env python3
"""HomeKit's types (issue #416): the service, characteristic and accessory category types, the characteristic value
enums and HMError's codes. Writes the header that declares them (sdk-src/Frameworks/HomeKit/HMTypes.h), HomeKit.framework's
definitions (frameworks/HomeKit/Types.m) and the overlay's tables (swift/overlays/HomeKit/Tables.swift). Type identifiers
are HAP's (the HomeKit Accessory Protocol's short UUIDs); the accessory category identifiers are isim's (Apple's are
private). Run it after editing the tables below; the outputs are committed."""
import os, re, sys


BASE = '-0000-1000-8000-0026BB765291'


def hap(short):
    return f'{int(short, 16):08X}{BASE}'


# service types: name, HAP short id, localized description
SERVICES = [
    ('AccessoryInformation', '3E', 'Accessory Information'), ('AirPurifier', 'BB', 'Air Purifier'),
    ('AirQualitySensor', '8D', 'Air Quality Sensor'), ('Battery', '96', 'Battery'),
    ('CameraControl', '111', 'Camera Control'), ('CameraRTPStreamManagement', '110', 'Camera Stream Management'),
    ('CarbonDioxideSensor', '97', 'Carbon Dioxide Sensor'), ('CarbonMonoxideSensor', '7F', 'Carbon Monoxide Sensor'),
    ('ContactSensor', '80', 'Contact Sensor'), ('Door', '81', 'Door'), ('Doorbell', '121', 'Doorbell'),
    ('Fan', '40', 'Fan'), ('Faucet', 'D7', 'Faucet'), ('FilterMaintenance', 'BA', 'Filter Maintenance'),
    ('GarageDoorOpener', '41', 'Garage Door Opener'), ('HeaterCooler', 'BC', 'Heater Cooler'),
    ('HumidifierDehumidifier', 'BD', 'Humidifier Dehumidifier'), ('HumiditySensor', '82', 'Humidity Sensor'),
    ('InputSource', 'D9', 'Input Source'), ('IrrigationSystem', 'CF', 'Irrigation System'), ('Label', 'CC', 'Label'),
    ('LeakSensor', '83', 'Leak Sensor'), ('LightSensor', '84', 'Light Sensor'), ('Lightbulb', '43', 'Lightbulb'),
    ('LockManagement', '44', 'Lock Management'), ('LockMechanism', '45', 'Lock Mechanism'),
    ('Microphone', '112', 'Microphone'), ('MotionSensor', '85', 'Motion Sensor'),
    ('OccupancySensor', '86', 'Occupancy Sensor'), ('Outlet', '47', 'Outlet'), ('SecuritySystem', '7E', 'Security System'),
    ('Slats', 'B9', 'Slats'), ('SmokeSensor', '87', 'Smoke Sensor'), ('Speaker', '113', 'Speaker'),
    ('StatefulProgrammableSwitch', '88', 'Stateful Programmable Switch'),
    ('StatelessProgrammableSwitch', '89', 'Stateless Programmable Switch'), ('Switch', '49', 'Switch'),
    ('Television', 'D8', 'Television'), ('TemperatureSensor', '8A', 'Temperature Sensor'),
    ('Thermostat', '4A', 'Thermostat'), ('Valve', 'D0', 'Valve'), ('VentilationFan', 'B7', 'Ventilation Fan'),
    ('WiFiRouter', '20A', 'Wi-Fi Router'), ('WiFiSatellite', '20F', 'Wi-Fi Satellite'), ('Window', '8B', 'Window'),
    ('WindowCovering', '8C', 'Window Covering'),
]

# characteristic types: name, HAP short id, format, units, (min, max, step), properties (r w n h), description
R, W, N = 'r', 'w', 'n'
CHARACTERISTICS = [
    ('Active', 'B0', 'uint8', None, (0, 1, 1), 'rwn', 'Active'),
    ('ActiveIdentifier', 'E7', 'uint32', None, None, 'rwn', 'Active Identifier'),
    ('AdminOnlyAccess', '1', 'bool', None, None, 'rwn', 'Admin Only Access'),
    ('AirParticulateDensity', '64', 'float', 'micrograms/m^3', (0, 1000, 1), 'rn', 'Air Particulate Density'),
    ('AirParticulateSize', '65', 'uint8', None, (0, 1, 1), 'rn', 'Air Particulate Size'),
    ('AirQuality', '95', 'uint8', None, (0, 5, 1), 'rn', 'Air Quality'),
    ('AudioFeedback', '5', 'bool', None, None, 'rwn', 'Audio Feedback'),
    ('BatteryLevel', '68', 'uint8', 'percentage', (0, 100, 1), 'rn', 'Battery Level'),
    ('Brightness', '8', 'int', 'percentage', (0, 100, 1), 'rwn', 'Brightness'),
    ('CarbonDioxideDetected', '92', 'uint8', None, (0, 1, 1), 'rn', 'Carbon Dioxide Detected'),
    ('CarbonDioxideLevel', '93', 'float', 'ppm', (0, 100000, 1), 'rn', 'Carbon Dioxide Level'),
    ('CarbonDioxidePeakLevel', '94', 'float', 'ppm', (0, 100000, 1), 'rn', 'Carbon Dioxide Peak Level'),
    ('CarbonMonoxideDetected', '69', 'uint8', None, (0, 1, 1), 'rn', 'Carbon Monoxide Detected'),
    ('CarbonMonoxideLevel', '90', 'float', 'ppm', (0, 100, 1), 'rn', 'Carbon Monoxide Level'),
    ('CarbonMonoxidePeakLevel', '91', 'float', 'ppm', (0, 100, 1), 'rn', 'Carbon Monoxide Peak Level'),
    ('ChargingState', '8F', 'uint8', None, (0, 2, 1), 'rn', 'Charging State'),
    ('ClosedCaptions', 'DD', 'uint8', None, (0, 1, 1), 'rwn', 'Closed Captions'),
    ('ColorTemperature', 'CE', 'uint32', None, (140, 500, 1), 'rwn', 'Color Temperature'),
    ('ConfiguredName', 'E3', 'string', None, None, 'rwn', 'Configured Name'),
    ('ContactState', '6A', 'uint8', None, (0, 1, 1), 'rn', 'Contact State'),
    ('CoolingThreshold', 'D', 'float', 'celsius', (10, 35, 0.1), 'rwn', 'Cooling Threshold'),
    ('CurrentAirPurifierState', 'A9', 'uint8', None, (0, 2, 1), 'rn', 'Current Air Purifier State'),
    ('CurrentDoorState', 'E', 'uint8', None, (0, 4, 1), 'rn', 'Current Door State'),
    ('CurrentFanState', 'AF', 'uint8', None, (0, 2, 1), 'rn', 'Current Fan State'),
    ('CurrentHeaterCoolerState', 'B1', 'uint8', None, (0, 3, 1), 'rn', 'Current Heater Cooler State'),
    ('CurrentHeatingCooling', 'F', 'uint8', None, (0, 2, 1), 'rn', 'Current Heating Cooling'),
    ('CurrentHorizontalTilt', '6C', 'int', 'arcdegrees', (-90, 90, 1), 'rn', 'Current Horizontal Tilt'),
    ('CurrentHumidifierDehumidifierState', 'B3', 'uint8', None, (0, 3, 1), 'rn', 'Current Humidifier Dehumidifier State'),
    ('CurrentLightLevel', '6B', 'float', 'lux', (0.0001, 100000, None), 'rn', 'Current Light Level'),
    ('CurrentLockMechanismState', '1D', 'uint8', None, (0, 3, 1), 'rn', 'Current Lock Mechanism State'),
    ('CurrentMediaState', 'E0', 'uint8', None, (0, 5, 1), 'rn', 'Current Media State'),
    ('CurrentPosition', '6D', 'uint8', 'percentage', (0, 100, 1), 'rn', 'Current Position'),
    ('CurrentRelativeHumidity', '10', 'float', 'percentage', (0, 100, 1), 'rn', 'Current Relative Humidity'),
    ('CurrentSecuritySystemState', '66', 'uint8', None, (0, 4, 1), 'rn', 'Current Security System State'),
    ('CurrentSlatState', 'AA', 'uint8', None, (0, 2, 1), 'rn', 'Current Slat State'),
    ('CurrentTemperature', '11', 'float', 'celsius', (0, 100, 0.1), 'rn', 'Current Temperature'),
    ('CurrentTilt', 'C1', 'int', 'arcdegrees', (-90, 90, 1), 'rn', 'Current Tilt'),
    ('CurrentVerticalTilt', '6E', 'int', 'arcdegrees', (-90, 90, 1), 'rn', 'Current Vertical Tilt'),
    ('CurrentVisibilityState', '135', 'uint8', None, (0, 3, 1), 'rn', 'Current Visibility State'),
    ('DehumidifierThreshold', 'C9', 'float', 'percentage', (0, 100, 1), 'rwn', 'Dehumidifier Threshold'),
    ('DigitalZoom', '11D', 'float', None, None, 'rwn', 'Digital Zoom'),
    ('FilterChangeIndication', 'AC', 'uint8', None, (0, 1, 1), 'rn', 'Filter Change Indication'),
    ('FilterLifeLevel', 'AB', 'float', None, (0, 100, 1), 'rn', 'Filter Life Level'),
    ('FilterResetChangeIndication', 'AD', 'uint8', None, (1, 1, 1), 'w', 'Filter Reset Change Indication'),
    ('FirmwareVersion', '52', 'string', None, None, 'r', 'Firmware Version'),
    ('HardwareVersion', '53', 'string', None, None, 'r', 'Hardware Version'),
    ('HeatingThreshold', '12', 'float', 'celsius', (0, 25, 0.1), 'rwn', 'Heating Threshold'),
    ('HoldPosition', '6F', 'bool', None, None, 'w', 'Hold Position'),
    ('Hue', '13', 'float', 'arcdegrees', (0, 360, 1), 'rwn', 'Hue'),
    ('HumidifierThreshold', 'CA', 'float', 'percentage', (0, 100, 1), 'rwn', 'Humidifier Threshold'),
    ('Identifier', 'E6', 'uint32', None, None, 'r', 'Identifier'),
    ('Identify', '14', 'bool', None, None, 'w', 'Identify'),
    ('ImageMirroring', '11F', 'bool', None, None, 'rwn', 'Image Mirroring'),
    ('ImageRotation', '11E', 'float', 'arcdegrees', (0, 270, 90), 'rwn', 'Image Rotation'),
    ('InUse', 'D2', 'uint8', None, (0, 1, 1), 'rn', 'In Use'),
    ('InputDeviceType', 'DC', 'uint8', None, (0, 6, 1), 'rn', 'Input Device Type'),
    ('InputEvent', '73', 'uint8', None, (0, 2, 1), 'rn', 'Input Event'),
    ('InputSourceType', 'DB', 'uint8', None, (0, 10, 1), 'rn', 'Input Source Type'),
    ('IsConfigured', 'D6', 'uint8', None, (0, 1, 1), 'rwn', 'Is Configured'),
    ('LabelIndex', 'CB', 'uint8', None, (1, 255, 1), 'r', 'Label Index'),
    ('LabelNamespace', 'CD', 'uint8', None, (0, 1, 1), 'r', 'Label Namespace'),
    ('LeakDetected', '70', 'uint8', None, (0, 1, 1), 'rn', 'Leak Detected'),
    ('LockManagementAutoSecureTimeout', '1A', 'uint32', 'seconds', None, 'rwn', 'Lock Management Auto Secure Timeout'),
    ('LockManagementControlPoint', '19', 'tlv8', None, None, 'w', 'Lock Management Control Point'),
    ('LockMechanismLastKnownAction', '1C', 'uint8', None, (0, 10, 1), 'rn', 'Lock Mechanism Last Known Action'),
    ('LockPhysicalControls', 'A7', 'uint8', None, (0, 1, 1), 'rwn', 'Lock Physical Controls'),
    ('Logs', '1F', 'tlv8', None, None, 'rn', 'Logs'),
    ('Manufacturer', '20', 'string', None, None, 'r', 'Manufacturer'),
    ('Model', '21', 'string', None, None, 'r', 'Model'),
    ('MotionDetected', '22', 'bool', None, None, 'rn', 'Motion Detected'),
    ('Mute', '11A', 'bool', None, None, 'rwn', 'Mute'),
    ('Name', '23', 'string', None, None, 'r', 'Name'),
    ('NightVision', '11B', 'bool', None, None, 'rwn', 'Night Vision'),
    ('NitrogenDioxideDensity', 'C4', 'float', 'micrograms/m^3', (0, 1000, 1), 'rn', 'Nitrogen Dioxide Density'),
    ('ObstructionDetected', '24', 'bool', None, None, 'rn', 'Obstruction Detected'),
    ('OccupancyDetected', '71', 'uint8', None, (0, 1, 1), 'rn', 'Occupancy Detected'),
    ('OpticalZoom', '11C', 'float', None, None, 'rwn', 'Optical Zoom'),
    ('OutletInUse', '26', 'bool', None, None, 'rn', 'Outlet In Use'),
    ('OutputState', '74', 'uint8', None, (0, 1, 1), 'rwn', 'Output State'),
    ('OzoneDensity', 'C3', 'float', 'micrograms/m^3', (0, 1000, 1), 'rn', 'Ozone Density'),
    ('PM10Density', 'C7', 'float', 'micrograms/m^3', (0, 1000, 1), 'rn', 'PM10 Density'),
    ('PM2_5Density', 'C6', 'float', 'micrograms/m^3', (0, 1000, 1), 'rn', 'PM2.5 Density'),
    ('PictureMode', 'E2', 'uint16', None, (0, 13, 1), 'rwn', 'Picture Mode'),
    ('PositionState', '72', 'uint8', None, (0, 2, 1), 'rn', 'Position State'),
    ('PowerModeSelection', 'DF', 'uint8', None, (0, 1, 1), 'w', 'Power Mode Selection'),
    ('PowerState', '25', 'bool', None, None, 'rwn', 'Power State'),
    ('ProgramMode', 'D1', 'uint8', None, (0, 2, 1), 'rn', 'Program Mode'),
    ('RemainingDuration', 'D4', 'uint32', 'seconds', (0, 3600, 1), 'rn', 'Remaining Duration'),
    ('RemoteKey', 'E1', 'uint8', None, (0, 16, 1), 'w', 'Remote Key'),
    ('RotationDirection', '28', 'int', None, (0, 1, 1), 'rwn', 'Rotation Direction'),
    ('RotationSpeed', '29', 'float', 'percentage', (0, 100, 1), 'rwn', 'Rotation Speed'),
    ('RouterStatus', '20E', 'uint8', None, (0, 1, 1), 'rn', 'Router Status'),
    ('Saturation', '2F', 'float', 'percentage', (0, 100, 1), 'rwn', 'Saturation'),
    ('SecuritySystemAlarmType', '8E', 'uint8', None, (0, 1, 1), 'rn', 'Security System Alarm Type'),
    ('SelectedStreamConfiguration', '117', 'tlv8', None, None, 'rw', 'Selected Stream Configuration'),
    ('SerialNumber', '30', 'string', None, None, 'r', 'Serial Number'),
    ('SetDuration', 'D3', 'uint32', 'seconds', (0, 3600, 1), 'rwn', 'Set Duration'),
    ('SetupStreamEndpoint', '118', 'tlv8', None, None, 'rw', 'Setup Stream Endpoint'),
    ('SlatType', 'C0', 'uint8', None, (0, 1, 1), 'r', 'Slat Type'),
    ('SmokeDetected', '76', 'uint8', None, (0, 1, 1), 'rn', 'Smoke Detected'),
    ('SoftwareVersion', '54', 'string', None, None, 'r', 'Software Version'),
    ('StatusActive', '75', 'bool', None, None, 'rn', 'Status Active'),
    ('StatusFault', '77', 'uint8', None, (0, 1, 1), 'rn', 'Status Fault'),
    ('StatusJammed', '78', 'uint8', None, (0, 1, 1), 'rn', 'Status Jammed'),
    ('StatusLowBattery', '79', 'uint8', None, (0, 1, 1), 'rn', 'Status Low Battery'),
    ('StatusTampered', '7A', 'uint8', None, (0, 1, 1), 'rn', 'Status Tampered'),
    ('StreamingStatus', '120', 'tlv8', None, None, 'rn', 'Streaming Status'),
    ('SulphurDioxideDensity', 'C5', 'float', 'micrograms/m^3', (0, 1000, 1), 'rn', 'Sulphur Dioxide Density'),
    ('SupportedAudioStreamConfiguration', '115', 'tlv8', None, None, 'r', 'Supported Audio Stream Configuration'),
    ('SupportedRTPConfiguration', '116', 'tlv8', None, None, 'r', 'Supported RTP Configuration'),
    ('SupportedVideoStreamConfiguration', '114', 'tlv8', None, None, 'r', 'Supported Video Stream Configuration'),
    ('SwingMode', 'B6', 'uint8', None, (0, 1, 1), 'rwn', 'Swing Mode'),
    ('TargetAirPurifierState', 'A8', 'uint8', None, (0, 1, 1), 'rwn', 'Target Air Purifier State'),
    ('TargetDoorState', '32', 'uint8', None, (0, 1, 1), 'rwn', 'Target Door State'),
    ('TargetFanState', 'BF', 'uint8', None, (0, 1, 1), 'rwn', 'Target Fan State'),
    ('TargetHeaterCoolerState', 'B2', 'uint8', None, (0, 2, 1), 'rwn', 'Target Heater Cooler State'),
    ('TargetHeatingCooling', '33', 'uint8', None, (0, 3, 1), 'rwn', 'Target Heating Cooling'),
    ('TargetHorizontalTilt', '7B', 'int', 'arcdegrees', (-90, 90, 1), 'rwn', 'Target Horizontal Tilt'),
    ('TargetHumidifierDehumidifierState', 'B4', 'uint8', None, (0, 2, 1), 'rwn', 'Target Humidifier Dehumidifier State'),
    ('TargetLockMechanismState', '1E', 'uint8', None, (0, 1, 1), 'rwn', 'Target Lock Mechanism State'),
    ('TargetMediaState', '137', 'uint8', None, (0, 2, 1), 'rwn', 'Target Media State'),
    ('TargetPosition', '7C', 'uint8', 'percentage', (0, 100, 1), 'rwn', 'Target Position'),
    ('TargetRelativeHumidity', '34', 'float', 'percentage', (0, 100, 1), 'rwn', 'Target Relative Humidity'),
    ('TargetSecuritySystemState', '67', 'uint8', None, (0, 3, 1), 'rwn', 'Target Security System State'),
    ('TargetTemperature', '35', 'float', 'celsius', (10, 38, 0.5), 'rwn', 'Target Temperature'),
    ('TargetTilt', 'C2', 'int', 'arcdegrees', (-90, 90, 1), 'rwn', 'Target Tilt'),
    ('TargetVerticalTilt', '7D', 'int', 'arcdegrees', (-90, 90, 1), 'rwn', 'Target Vertical Tilt'),
    ('TargetVisibilityState', '134', 'uint8', None, (0, 1, 1), 'rwn', 'Target Visibility State'),
    ('TemperatureUnits', '36', 'uint8', None, (0, 1, 1), 'rwn', 'Temperature Units'),
    ('ValveType', 'D5', 'uint8', None, (0, 3, 1), 'rn', 'Valve Type'),
    ('Version', '37', 'string', None, None, 'r', 'Version'),
    ('VolatileOrganicCompoundDensity', 'C8', 'float', 'micrograms/m^3', (0, 1000, 1), 'rn', 'Volatile Organic Compound Density'),
    ('Volume', '119', 'uint8', 'percentage', (0, 100, 1), 'rwn', 'Volume'),
    ('VolumeControlType', 'E9', 'uint8', None, (0, 3, 1), 'rn', 'Volume Control Type'),
    ('VolumeSelector', 'EA', 'uint8', None, (0, 1, 1), 'w', 'Volume Selector'),
    ('WANStatusList', '211', 'tlv8', None, None, 'rn', 'WAN Status List'),
    ('WaterLevel', 'B5', 'float', 'percentage', (0, 100, 1), 'rn', 'Water Level'),
    ('WiFiSatelliteStatus', '21E', 'uint8', None, (0, 2, 1), 'rn', 'Wi-Fi Satellite Status'),
]

# accessory categories: name, HAP category id, localized description (isim's identifiers: Apple's are private)
CATEGORIES = [
    ('Other', 1, 'Other'), ('Bridge', 2, 'Bridge'), ('Fan', 3, 'Fan'), ('GarageDoorOpener', 4, 'Garage Door Opener'),
    ('Lightbulb', 5, 'Lightbulb'), ('DoorLock', 6, 'Door Lock'), ('Outlet', 7, 'Outlet'), ('Switch', 8, 'Switch'),
    ('Thermostat', 9, 'Thermostat'), ('Sensor', 10, 'Sensor'), ('SecuritySystem', 11, 'Security System'),
    ('Door', 12, 'Door'), ('Window', 13, 'Window'), ('WindowCovering', 14, 'Window Covering'),
    ('ProgrammableSwitch', 15, 'Programmable Switch'), ('RangeExtender', 16, 'Range Extender'),
    ('IPCamera', 17, 'IP Camera'), ('VideoDoorbell', 18, 'Video Doorbell'), ('AirPurifier', 19, 'Air Purifier'),
    ('AirHeater', 20, 'Air Heater'), ('AirConditioner', 21, 'Air Conditioner'), ('AirHumidifier', 22, 'Air Humidifier'),
    ('AirDehumidifier', 23, 'Air Dehumidifier'), ('AirPort', 27, 'AirPort'), ('Speaker', 26, 'Speaker'),
    ('Sprinkler', 28, 'Sprinkler'), ('Faucet', 29, 'Faucet'), ('ShowerHead', 30, 'Shower Head'),
    ('Television', 31, 'Television'), ('TelevisionSetTopBox', 35, 'Set-Top Box'),
    ('TelevisionStreamingStick', 36, 'Streaming Stick'), ('WiFiRouter', 33, 'Wi-Fi Router'),
    ('AudioReceiver', 34, 'Audio Receiver'),
]

# characteristic value enums: name, [(case, value)], the characteristic type whose value it is
ENUMS = [
    ('ChargingState', [('None', 0), ('InProgress', 1), ('NotChargeable', 2)]),
    ('ContactState', [('Detected', 0), ('None', 1)]),
    ('BatteryStatus', [('Normal', 0), ('Low', 1)]),
    ('InputEvent', [('SinglePress', 0), ('DoublePress', 1), ('LongPress', 2)]),
    ('PowerModeSelection', [('Show', 0), ('Hide', 1)]),
    ('TemperatureUnit', [('Celsius', 0), ('Fahrenheit', 1)]),
    ('HeatingCooling', [('Off', 0), ('Heat', 1), ('Cool', 2), ('Auto', 3)]),
    ('CurrentHeatingCooling', [('Off', 0), ('Heat', 1), ('Cool', 2)]),
    ('TargetHeaterCoolerState', [('Automatic', 0), ('Heat', 1), ('Cool', 2)]),
    ('CurrentHeaterCoolerState', [('Inactive', 0), ('Idle', 1), ('Heating', 2), ('Cooling', 3)]),
    ('CurrentHumidifierDehumidifierState', [('Inactive', 0), ('Idle', 1), ('Humidifying', 2), ('Dehumidifying', 3)]),
    ('TargetHumidifierDehumidifierState', [('Automatic', 0), ('Humidify', 1), ('Dehumidify', 2)]),
    ('AirQuality', [('Unknown', 0), ('Excellent', 1), ('Good', 2), ('Fair', 3), ('Inferior', 4), ('Poor', 5)]),
    ('AirParticulateSize', [('Size2_5', 0), ('Size10', 1)]),
    ('SmokeDetectionStatus', [('None', 0), ('Detected', 1)]),
    ('CarbonDioxideDetectionStatus', [('NotDetected', 0), ('Detected', 1)]),
    ('CarbonMonoxideDetectionStatus', [('NotDetected', 0), ('Detected', 1)]),
    ('CurrentFanState', [('Inactive', 0), ('Idle', 1), ('Active', 2)]),
    ('TargetFanState', [('Manual', 0), ('Automatic', 1)]),
    ('RotationDirection', [('Clockwise', 0), ('CounterClockwise', 1)]),
    ('SwingMode', [('Disabled', 0), ('Enabled', 1)]),
    ('CurrentAirPurifierState', [('Inactive', 0), ('Idle', 1), ('Active', 2)]),
    ('TargetAirPurifierState', [('Manual', 0), ('Automatic', 1)]),
    ('FilterChange', [('NotNeeded', 0), ('Needed', 1)]),
    ('ValveType', [('GenericValve', 0), ('Irrigation', 1), ('ShowerHead', 2), ('WaterFaucet', 3)]),
    ('LeakStatus', [('None', 0), ('Detected', 1)]),
    ('DoorState', [('Open', 0), ('Closed', 1), ('Opening', 2), ('Closing', 3), ('Stopped', 4)]),
    ('TargetDoorState', [('Open', 0), ('Closed', 1)]),
    ('PositionState', [('Closing', 0), ('Opening', 1), ('Stopped', 2)]),
    ('JammedStatus', [('None', 0), ('Jammed', 1)]),
    ('SlatType', [('Horizontal', 0), ('Vertical', 1)]),
    ('CurrentSlatState', [('Stationary', 0), ('Jammed', 1), ('Oscillating', 2)]),
    ('LockMechanismLastKnownAction', [('SecuredUsingPhysicalMovementInterior', 0), ('UnsecuredUsingPhysicalMovementInterior', 1),
                                      ('SecuredUsingPhysicalMovementExterior', 2), ('UnsecuredUsingPhysicalMovementExterior', 3),
                                      ('SecuredWithKeypad', 4), ('UnsecuredWithKeypad', 5), ('SecuredRemotely', 6),
                                      ('UnsecuredRemotely', 7), ('SecuredWithAutomaticSecureTimeout', 8),
                                      ('SecuredUsingPhysicalMovement', 9), ('UnsecuredUsingPhysicalMovement', 10)]),
    ('LockPhysicalControlsState', [('NotLocked', 0), ('Locked', 1)]),
    ('LockMechanismState', [('Unsecured', 0), ('Secured', 1), ('Jammed', 2), ('Unknown', 3)]),
    ('TargetLockMechanismState', [('Unsecured', 0), ('Secured', 1)]),
    ('RemoteKey', [('Rewind', 0), ('FastForward', 1), ('NextTrack', 2), ('PreviousTrack', 3), ('ArrowUp', 4), ('ArrowDown', 5),
                   ('ArrowLeft', 6), ('ArrowRight', 7), ('Select', 8), ('Back', 9), ('Exit', 10), ('PlayPause', 11),
                   ('Play', 12), ('Pause', 13), ('Menu', 14), ('Info', 15), ('Home', 16)]),
    ('CurrentSecuritySystemState', [('StayArm', 0), ('AwayArm', 1), ('NightArm', 2), ('Disarmed', 3), ('Triggered', 4)]),
    ('TargetSecuritySystemState', [('StayArm', 0), ('AwayArm', 1), ('NightArm', 2), ('Disarm', 3)]),
    ('OccupancyStatus', [('NotOccupied', 0), ('Occupied', 1)]),
    ('SecuritySystemAlarmType', [('NoAlarm', 0), ('Unknown', 1)]),
    ('VolumeSelector', [('VolumeIncrement', 0), ('VolumeDecrement', 1)]),
    ('VolumeControlType', [('None', 0), ('Relative', 1), ('RelativeWithCurrent', 2), ('Absolute', 3)]),
    ('ClosedCaptions', [('Disabled', 0), ('Enabled', 1)]),
    ('PictureMode', [('Standard', 0), ('Calibrated', 1), ('Dark', 2), ('Vivid', 3), ('Game', 4), ('Computer', 5),
                     ('Custom1', 6), ('Custom2', 7), ('Custom3', 8), ('Movie', 9), ('Night', 10), ('Photo', 11),
                     ('Sport', 12), ('Bright', 13)]),
    ('ActivationState', [('Inactive', 0), ('Active', 1)]),
    ('TamperedStatus', [('None', 0), ('Tampered', 1)]),
    ('StatusFault', [('NoFault', 0), ('GeneralFault', 1)]),
    ('UsageState', [('NotInUse', 0), ('InUse', 1)]),
    ('ConfigurationState', [('NotConfigured', 0), ('Configured', 1)]),
    ('ProgramMode', [('NotScheduled', 0), ('Scheduled', 1), ('ScheduleOverriddenToManual', 2)]),
    ('WiFiSatelliteStatus', [('Unknown', 0), ('Connected', 1), ('NotConnected', 2)]),
    ('TargetMediaState', [('Play', 0), ('Pause', 1), ('Stop', 2)]),
    ('RouterStatus', [('Ready', 0), ('NotReady', 1)]),
    ('CurrentMediaState', [('Playing', 0), ('Paused', 1), ('Stopped', 2), ('Unknown', 3), ('Loading', 4), ('Interrupted', 5)]),
    ('CurrentVisibilityState', [('Shown', 0), ('Hidden', 1), ('Connected', 2), ('AlwaysShown', 3)]),
    ('TargetVisibilityState', [('Show', 0), ('Hide', 1)]),
    ('LabelNamespace', [('Dot', 0), ('Numeral', 1)]),
    ('InputDeviceType', [('Other', 0), ('TV', 1), ('Recording', 2), ('Tuner', 3), ('Playback', 4), ('AudioSystem', 5), ('None', 6)]),
    ('InputSourceType', [('Other', 0), ('HomeScreen', 1), ('Tuner', 2), ('HDMI', 3), ('CompositeVideo', 4), ('SVideo', 5),
                         ('ComponentVideo', 6), ('DVI', 7), ('AirPlay', 8), ('USB', 9), ('Application', 10)]),
]

# HMError.Code: in HMError.h's order
ERRORS = [
    ('UnexpectedError', -1), ('AlreadyExists', 1), ('NotFound', 2), ('InvalidParameter', 3), ('AccessoryNotReachable', 4),
    ('ReadOnlyCharacteristic', 5), ('WriteOnlyCharacteristic', 6), ('NotificationNotSupported', 7), ('OperationTimedOut', 8),
    ('AccessoryPoweredOff', 9), ('AccessDenied', 10), ('ObjectAssociatedToAnotherHome', 11), ('ObjectNotAssociatedToAnyHome', 12),
    ('ObjectAlreadyAssociatedToHome', 13), ('AccessoryIsBusy', 14), ('OperationInProgress', 15), ('AccessoryOutOfResources', 16),
    ('InsufficientPrivileges', 17), ('AccessoryPairingFailed', 18), ('InvalidDataFormatSpecified', 19), ('NilParameter', 20),
    ('UnconfiguredParameter', 21), ('InvalidClass', 22), ('OperationCancelled', 23), ('RoomForHomeCannotBeInZone', 24),
    ('NoActionsInActionSet', 25), ('NoRegisteredActionSets', 26), ('MissingParameter', 27), ('FireDateInPast', 28),
    ('RoomForHomeCannotBeUpdated', 29), ('ActionInAnotherActionSet', 30), ('ObjectWithSimilarNameExistsInHome', 31),
    ('HomeWithSimilarNameExists', 32), ('RenameWithSimilarName', 33), ('CannotRemoveNonBridgeAccessory', 34),
    ('NameContainsProhibitedCharacters', 35), ('NameDoesNotStartWithValidCharacters', 36), ('UserIDNotEmailAddress', 37),
    ('UserDeclinedAddingUser', 38), ('UserDeclinedRemovingUser', 39), ('UserDeclinedInvite', 40), ('UserManagementFailed', 41),
    ('RecurrenceTooSmall', 42), ('InvalidValueType', 43), ('ValueLowerThanMinimum', 44), ('ValueHigherThanMaximum', 45),
    ('StringLongerThanMaximum', 46), ('HomeAccessNotAuthorized', 47), ('OperationNotSupported', 48),
    ('MaximumObjectLimitReached', 49), ('AccessorySentInvalidResponse', 50), ('StringShorterThanMinimum', 51),
    ('GenericError', 52), ('SecurityFailure', 53), ('CommunicationFailure', 54), ('MessageAuthenticationFailed', 55),
    ('InvalidMessageSize', 56), ('AccessoryDiscoveryFailed', 57), ('ClientRequestError', 58), ('AccessoryResponseError', 59),
    ('NameDoesNotEndWithValidCharacters', 60), ('AccessoryIsBlocked', 61), ('InvalidAssociatedServiceType', 62),
    ('ActionSetExecutionFailed', 63), ('ActionSetExecutionPartialSuccess', 64), ('ActionSetExecutionInProgress', 65),
    ('AccessoryOutOfCompliance', 66), ('DataResetFailure', 67), ('NotificationAlreadyEnabled', 68),
    ('RecurrenceMustBeOnSpecifiedBoundaries', 69), ('DateMustBeOnSpecifiedBoundaries', 70),
    ('CannotActivateTriggerTooFarInFuture', 71), ('RecurrenceTooLarge', 72), ('ReadWritePartialSuccess', 73),
    ('ReadWriteFailure', 74), ('NotSignedIntoiCloud', 75), ('KeychainSyncNotEnabled', 76), ('CloudDataSyncInProgress', 77),
    ('NetworkUnavailable', 78), ('AddAccessoryFailed', 79), ('MissingEntitlement', 80), ('CannotUnblockNonBridgeAccessory', 81),
    ('DeviceLocked', 82), ('CannotRemoveBuiltinActionSet', 83), ('LocationForHomeDisabled', 84),
    ('NotAuthorizedForLocationServices', 85), ('ReferToUserManual', 86), ('InvalidOrMissingAuthorizationData', 87),
    ('BridgedAccessoryNotReachable', 88), ('NotAuthorizedForMicrophoneAccess', 89), ('IncompatibleNetwork', 90),
    ('NoHomeHub', 91), ('NoCompatibleHomeHub', 92), ('IncompatibleAccessory', 93),
    ('ObjectWithSimilarNameExists', 95), ('OwnershipFailure', 96), ('MaximumAccessoriesOfTypeInHome', 97),
    ('WiFiCredentialGenerationFailed', 98), ('EnterpriseNetworkNotSupported', 99), ('TimedOutWaitingForAccessory', 100),
    ('AccessoryCommunicationFailure', 101), ('FailedToJoinNetwork', 102), ('AccessoryIsSuspended', 103),
    ('PartialCommunicationFailure', 104), ('HomeUpgradeRequired', 105)
]

ACTION_SET_TYPES = [('WakeUp', 'HMActionSetTypeWakeUp'), ('Sleep', 'HMActionSetTypeSleep'),
                    ('HomeDeparture', 'HMActionSetTypeHomeDeparture'), ('HomeArrival', 'HMActionSetTypeHomeArrival'),
                    ('UserDefined', 'HMActionSetTypeUserDefined'), ('TriggerOwned', 'HMActionSetTypeTriggerOwned')]
FORMATS = ['Bool', 'Int', 'Float', 'String', 'Array', 'Dictionary', 'UInt8', 'UInt16', 'UInt32', 'UInt64', 'Data', 'TLV8']
UNITS = [('Celsius', 'celsius'), ('Fahrenheit', 'fahrenheit'), ('Percentage', 'percentage'), ('ArcDegree', 'arcdegrees'),
         ('Seconds', 'seconds'), ('Lux', 'lux'), ('PartsPerMillion', 'ppm'), ('MicrogramsPerCubicMeter', 'micrograms/m^3')]
PROPERTIES = [('SupportsEventNotification', 'HMCharacteristicPropertySupportsEventNotification'),
              ('Readable', 'HMCharacteristicPropertyReadable'), ('Writable', 'HMCharacteristicPropertyWritable'),
              ('Hidden', 'HMCharacteristicPropertyHidden'),
              ('RequiresAuthorizationData', 'HMCharacteristicPropertyRequiresAuthorizationData')]



def lower_camel(s):
    m = re.match(r'^([A-Z]+)(?=[A-Z][a-z]|$|[0-9_])', s)
    if m:
        run = m.group(1)
        return run.lower() + s[len(run):]
    return s[0].lower() + s[1:]


def swift_case(enum, case):
    if enum == 'VolumeSelector':
        return lower_camel(case)
    return lower_camel(case)


def main():
    ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    h, m, sw = [], [], []

    h.append('')
    h.append('HM_EXTERN NSErrorDomain const HMErrorDomain;')
    for name, short, desc in SERVICES:
        h.append(f'HM_EXTERN NSString * const HMServiceType{name};')
        m.append(f'NSString * const HMServiceType{name} = @"{hap(short)}";')
    for c in CHARACTERISTICS:
        h.append(f'HM_EXTERN NSString * const HMCharacteristicType{c[0]};')
        m.append(f'NSString * const HMCharacteristicType{c[0]} = @"{hap(c[1])}";')
    for name, num, desc in CATEGORIES:
        h.append(f'HM_EXTERN NSString * const HMAccessoryCategoryType{name};')
        m.append(f'NSString * const HMAccessoryCategoryType{name} = @"{num:08X}-0000-1000-8000-0A0F1F0E0000";')
    for short, full in ACTION_SET_TYPES:
        h.append(f'HM_EXTERN NSString * const {full};')
        m.append(f'NSString * const {full} = @"{full}";')
    for f in FORMATS:
        h.append(f'HM_EXTERN NSString * const HMCharacteristicMetadataFormat{f};')
        m.append(f'NSString * const HMCharacteristicMetadataFormat{f} = @"{f.lower()}";')
    for name, v in UNITS:
        h.append(f'HM_EXTERN NSString * const HMCharacteristicMetadataUnits{name};')
        m.append(f'NSString * const HMCharacteristicMetadataUnits{name} = @"{v}";')
    for name, full in PROPERTIES:
        # NS_SWIFT_NAME keeps ...Notification a String (Swift would import it as NSNotification.Name)
        h.append(f'HM_EXTERN NSString * const {full}' + (f' NS_SWIFT_NAME({full})' if full.endswith('Notification') else '') + ';')
        m.append(f'NSString * const {full} = @"{full}";')
    h.append('HM_EXTERN NSString * const HMCharacteristicKeyPath;')
    h.append('HM_EXTERN NSString * const HMCharacteristicValueKeyPath;')
    h.append('HM_EXTERN NSString * const HMPresenceKeyPath;')
    h.append('HM_EXTERN NSString * const HMUserFailedAccessoriesKey;')
    m.append('NSString * const HMCharacteristicKeyPath = @"characteristic";')
    m.append('NSString * const HMCharacteristicValueKeyPath = @"value";')
    m.append('NSString * const HMPresenceKeyPath = @"presence";')
    m.append('NSString * const HMUserFailedAccessoriesKey = @"kFailedAccessoriesKey";')
    m.append('NSErrorDomain const HMErrorDomain = @"HMErrorDomain";')
    h.append('')
    for enum, cases in ENUMS:
        h.append(f'typedef NS_ENUM(NSInteger, HMCharacteristicValue{enum}) {{')
        for case, v in cases:
            cname = f'HMCharacteristicValue{enum}{case}'
            if enum == 'AirParticulateSize':
                cname = f'HMCharacteristicValueAirParticulate{case}'
            if enum == 'VolumeSelector':
                cname = f'HMCharacteristicValueVolumeSelector{case[len("Volume"):]}'
            h.append(f'    {cname} NS_SWIFT_NAME({swift_case(enum, case)}) = {v},')
        h.append('};')
    h.append('')
    h.append('#if !defined(__swift__)          // Swift: HMError (the overlay\'s, with HMError.Code)')
    h.append('typedef NS_ERROR_ENUM(HMErrorDomain, HMErrorCode) {')
    for name, v in ERRORS:
        h.append(f'    HMErrorCode{name} = {v},')
    h.append('    HMErrorCodeIncompatibleHomeHub = HMErrorCodeIncompatibleAccessory,')
    h.append('};')
    h.append('#endif')


    HEADER = ['// HomeKit\'s types: generated by isim/tools/homekit-types.py (do not edit by hand)', '#import <Foundation/Foundation.h>',
              '', 'NS_ASSUME_NONNULL_BEGIN', '']
    open(os.path.join(ROOT, 'sdk-src/Frameworks/HomeKit/HMTypes.h'), 'w').write('\n'.join(HEADER + h[1:] + ['', 'NS_ASSUME_NONNULL_END']) + '\n')
    open(os.path.join(ROOT, 'frameworks/HomeKit/Types.m'), 'w').write(
        '// HomeKit\'s constants: generated by isim/tools/homekit-types.py (do not edit by hand)\n#import <HomeKit/HomeKit.h>\n\n'
        + '\n'.join(m) + '\n')


    def num(x):
        return 'nil' if x is None else repr(float(x)) if isinstance(x, float) else str(x)


    sw.append('// isim HomeKit: the type tables (generated by isim/tools/homekit-types.py with the header\'s constants, whose')
    sw.append('// symbols this overlay cannot link: HomeKit.framework links it). Type identifiers are HAP\'s.')
    sw.append('import Foundation\n')
    sw.append('struct _HMCharacteristicInfo { let name: String, description: String, format: String, units: String?, min: Double?, max: Double?, step: Double?, properties: String }\n')
    sw.append('enum _HMTypes {')
    sw.append('    static let services: [String: (name: String, description: String)] = [')
    for name, short, desc in SERVICES:
        sw.append(f'        "{hap(short)}": ("{name}", "{desc}"),')
    sw.append('    ]')
    sw.append('    static let characteristics: [String: _HMCharacteristicInfo] = [')
    for name, short, fmt, units, rng, props, desc in CHARACTERISTICS:
        mn, mx, st = rng if rng else (None, None, None)
        u = f'"{units}"' if units else 'nil'
        sw.append(f'        "{hap(short)}": _HMCharacteristicInfo(name: "{name}", description: "{desc}", format: "{fmt}", units: {u}, '
                  f'min: {num(mn)}, max: {num(mx)}, step: {num(st)}, properties: "{props}"),')
    sw.append('    ]')
    sw.append('    static let categories: [String: (name: String, description: String)] = [')
    for name, n, desc in CATEGORIES:
        sw.append(f'        "{n:08X}-0000-1000-8000-0A0F1F0E0000": ("{name}", "{desc}"),')
    sw.append('    ]')
    sw.append('    /// a service, characteristic or category type by its constant\'s name (HMServiceTypeLightbulb -> "Lightbulb")')
    sw.append('    static func service(_ name: String) -> String { services.first { $0.value.name == name }!.key }')
    sw.append('    static func characteristic(_ name: String) -> String { characteristics.first { $0.value.name == name }!.key }')
    sw.append('    static func category(_ name: String) -> String { categories.first { $0.value.name == name }!.key }')
    sw.append('    static let actionSetTypes = [' + ', '.join(f'"{full}"' for _, full in ACTION_SET_TYPES) + ']')
    sw.append('    static let propertyReadable = "HMCharacteristicPropertyReadable", propertyWritable = "HMCharacteristicPropertyWritable"')
    sw.append('    static let propertyEvents = "HMCharacteristicPropertySupportsEventNotification", propertyHidden = "HMCharacteristicPropertyHidden"')
    sw.append('}\n')

    sw.append('public struct HMError: Error, CustomNSError, Hashable, Sendable {')
    sw.append('    public enum Code: Int, @unchecked Sendable, Equatable, Hashable {')
    for name, v in ERRORS:
        sw.append(f'        case {lower_camel(name)} = {v}')
    sw.append('        public static var incompatibleHomeHub: Code { .incompatibleAccessory }')
    sw.append('    }')
    sw.append('    public let code: Code')
    sw.append('    let _message: String?')
    sw.append('    public init(_ code: Code) { self.code = code; _message = nil }')
    sw.append('    init(_ code: Code, _ message: String) { self.code = code; _message = message }')
    sw.append('    public static var errorDomain: String { "HMErrorDomain" }')
    sw.append('    public var errorCode: Int { code.rawValue }')
    sw.append('    public var errorUserInfo: [String: Any] { _message.map { [NSLocalizedDescriptionKey: $0] } ?? [:] }')
    sw.append('    public static func == (a: HMError, b: HMError) -> Bool { a.code == b.code }')
    sw.append('    public func hash(into h: inout Hasher) { h.combine(code) }')
    for name, v in ERRORS:
        sw.append(f'    public static var {lower_camel(name)}: Code {{ .{lower_camel(name)} }}')
    sw.append('    public static var incompatibleHomeHub: Code { .incompatibleAccessory }')
    sw.append('}')
    open(os.path.join(ROOT, 'swift/overlays/HomeKit/Tables.swift'), 'w').write('\n'.join(sw) + '\n')


if __name__ == '__main__':
    main()
