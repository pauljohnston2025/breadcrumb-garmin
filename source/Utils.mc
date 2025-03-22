import Toybox.Lang;
import Toybox.System;

const FLOAT_MIN = -340282346638528859811704183484516925440.0000000000000000;
const FLOAT_MAX = 340282346638528859811704183484516925440.0000000000000000;

(:release)
function isSimulator() as Boolean {
  return false;
}

(:debug)
function isSimulator() as Boolean {
  var simulators = ["9f8a103dbb3fe23a4c02a601d429c4c677f2908d"];
  System.println("deviceID: " + System.getDeviceSettings().uniqueIdentifier);
  if (simulators.indexOf(System.getDeviceSettings().uniqueIdentifier) > -1)
  {
    System.println("simulator detected");
    return true;
  }

  return false;
}

function maxF(lhs as Float, rhs as Float) as Float {
  if (lhs > rhs) {
    return lhs;
  }

  return rhs;
}

function minF(lhs as Float, rhs as Float) as Float {
  if (lhs < rhs) {
    return lhs;
  }

  return rhs;
}

function abs(val as Float) as Float {
  if (val < 0)
  {
    return -val;
  }

  return val;
}

// from https://forums.garmin.com/developer/connect-iq/f/discussion/338071/testing-for-nan/1777041#1777041
function isnan(a as Float) as Boolean {
  return a != a;
}