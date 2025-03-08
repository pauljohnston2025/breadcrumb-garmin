import Toybox.Lang;

const FLOAT_MIN = -340282346638528859811704183484516925440.0000000000000000;
const FLOAT_MAX = 340282346638528859811704183484516925440.0000000000000000;

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