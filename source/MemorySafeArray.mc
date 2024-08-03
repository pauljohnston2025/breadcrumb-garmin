import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Application;

// this is to solve the issue of slice() returning a new array
// we want to instead allocate teh array to a max length, the just remove the last elements
// ie. bigArray = bigArray.slice(0, 100) will result in bigArray + 100 extra items untill big array is garbage collected
// this class allows us to just reduce bigArray to 100 elements in one go
class MemorySafeArray {
  var _internalArrayBuffer as Array<Float> = [];
  var _size = 0;

  function get(i as Number) as Float
  {
    return _internalArrayBuffer[i];
  }

  function add(item as Float) as Void
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

  function size() as Number
  {
    return _size;
  }

  function resize(size as Number) as Void
  {
    if (size > _internalArrayBuffer.size())
    {
        throw new Exception();
    }

    _size = size;
  }
}
