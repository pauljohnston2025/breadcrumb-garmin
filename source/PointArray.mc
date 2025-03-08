import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Application;

const ARRAY_POINT_SIZE = 3;

class RectangularPoint {
  var x as Float;
  var y as Float;
  var altitude as Float;

  function initialize(_x as Float, _y as Float, _altitude as Float) {
    x = _x;
    y = _y;
    altitude = _altitude;
  }

  function distanceTo(point as RectangularPoint) as Decimal
  {
      var xDist = point.x - x;
      var yDist = point.y - y;
      return Math.sqrt(xDist * xDist + yDist * yDist);
  }

  function valid() as Boolean
  {
    return !isnan(x) && !isnan(y) && !isnan(altitude);
  }
}

// this is to solve the issue of slice() returning a new array
// we want to instead allocate teh array to a max length, the just remove the last elements
// ie. bigArray = bigArray.slice(0, 100) will result in bigArray + 100 extra items untill big array is garbage collected
// this class allows us to just reduce bigArray to 100 elements in one go
class PointArray {
  var _internalArrayBuffer as Array<Float> = [];
  var _size as Number = 0;

  // not used, since wqe want to do optimised reads from the raw array
  // function get(i as Number) as Float
  // {
  //   return _internalArrayBuffer[i];
  // }

  function add(point as RectangularPoint) as Void
  {
    _add(point.x);
    _add(point.y);
    _add(point.altitude);
  }

  function removeLastCountPoints(count as Number) as Void 
  {
    resize(size() - count * ARRAY_POINT_SIZE);
  }

  function lastPoint() as RectangularPoint or Null 
  {
    return getPoint(pointSize() - 1);
  }
  
  function firstPoint() as RectangularPoint or Null 
  {
    return getPoint(0);
  }

  function getPoint(i as Number) as RectangularPoint or Null 
  {
    if (i<0)
    {
      return null;
    }

    if (i>=pointSize())
    {
      return null;
    }

    return new RectangularPoint(_internalArrayBuffer[i * ARRAY_POINT_SIZE],
                              _internalArrayBuffer[i * ARRAY_POINT_SIZE + 1],
                              _internalArrayBuffer[i * ARRAY_POINT_SIZE + 2]);
  }

  function restrictPoints(maPoints as Number) as Void {
    // make sure we only have an acceptancbe amount of points
    // current process is to cull every second point
    // this means near the end of the track, we will have lots of close points
    // the start of the track will start getting more and more granular every
    // time we cull points
    if (size() / ARRAY_POINT_SIZE < maPoints) {
      return;
    }

    // we need to do this without creating a new array, since we do not want to
    // double the memory size temporarily
    // slice() will create a new array, we avoid this by using our custom class
    var j = 0;
    for (var i = 0; i < size(); i += ARRAY_POINT_SIZE * 2) {
      _internalArrayBuffer[j] = _internalArrayBuffer[i];
      _internalArrayBuffer[j + 1] = _internalArrayBuffer[i + 1];
      _internalArrayBuffer[j + 2] = _internalArrayBuffer[i + 2];
      j += ARRAY_POINT_SIZE;
    }

    resize(ARRAY_POINT_SIZE * maPoints / 2);
  }

  function _add(item as Float) as Void
  {
    if (_size < _internalArrayBuffer.size())
    {
        _internalArrayBuffer[_size] = item;
        ++_size;
        return;
    }
        
    _internalArrayBuffer.add(item);
    // we could use ++_size, as it should never be larger than the size of the internal array
    _size = _internalArrayBuffer.size();
  }

  // the raw size
  function size() as Number
  {
    return _size;
  }

  // the number of points
  function pointSize() as Number
  {
    return size() / ARRAY_POINT_SIZE;
  }

  function resize(size as Number) as Void
  {
    if (size > _internalArrayBuffer.size())
    {
        throw new Exception();
    }

    if (size < 0)
    {
      size = 0;
    }

    _size = size;
  }

  function clear() as Void {
    resize(0);
  }
}
