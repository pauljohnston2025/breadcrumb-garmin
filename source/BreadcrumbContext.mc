import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;

class BreadcrumbContext {
  var _breadcrumbRenderer as BreadcrumbRenderer;
  var _route as BreadcrumbTrack or Null;
  var _track as BreadcrumbTrack;

  // Set the label of the data field here.
  function initialize() {
    _track = new BreadcrumbTrack();
    _breadcrumbRenderer = new BreadcrumbRenderer();

    // inital test route, will be removed at a later date
    // var rawCoords = [
    //   [ -27.297514, 152.753860 ], [ -27.297509, 152.753848 ],
    //   [ -27.297438, 152.753839 ], [ -27.297400, 152.753827 ],
    //   [ -27.297367, 152.753817 ], [ -27.297353, 152.753816 ],
    //   [ -27.297332, 152.753811 ], [ -27.297309, 152.753806 ],
    //   [ -27.297289, 152.753797 ], [ -27.297277, 152.753793 ],
    //   [ -27.297266, 152.753791 ], [ -27.297260, 152.753789 ],
    //   [ -27.297251, 152.753783 ], [ -27.297243, 152.753779 ],
    //   [ -27.296854, 152.753722 ], [ -27.296445, 152.753782 ],
    //   [ -27.296069, 152.754457 ], [ -27.295623, 152.755619 ],
    //   [ -27.295187, 152.757002 ], [ -27.295528, 152.758083 ],
    //   [ -27.295601, 152.759104 ], [ -27.295467, 152.760068 ],
    //   [ -27.295026, 152.762026 ], [ -27.294955, 152.763041 ],
    //   [ -27.294894, 152.764648 ], [ -27.294592, 152.766201 ],
    //   [ -27.294732, 152.767209 ], [ -27.296218, 152.767723 ],
    //   [ -27.297393, 152.768442 ], [ -27.298084, 152.768516 ],
    //   [ -27.299137, 152.769156 ], [ -27.300144, 152.769483 ],
    //   [ -27.301310, 152.770309 ], [ -27.301524, 152.771727 ],
    //   [ -27.300998, 152.772259 ], [ -27.300814, 152.772659 ],
    //   [ -27.299807, 152.773792 ], [ -27.299565, 152.774460 ],
    //   [ -27.299743, 152.774257 ], [ -27.299872, 152.773632 ],
    //   [ -27.300726, 152.772599 ], [ -27.301410, 152.771877 ],
    //   [ -27.301647, 152.770617 ], [ -27.303042, 152.770881 ],
    //   [ -27.303328, 152.770991 ], [ -27.302099, 152.770411 ],
    //   [ -27.301988, 152.770390 ], [ -27.300927, 152.770159 ],
    //   [ -27.299082, 152.769110 ], [ -27.297414, 152.768498 ],
    //   [ -27.295843, 152.767761 ], [ -27.294908, 152.764974 ],
    //   [ -27.294980, 152.762144 ], [ -27.295515, 152.759859 ],
    //   [ -27.295467, 152.757536 ], [ -27.295663, 152.755540 ],
    //   [ -27.297046, 152.753708 ],
    // ];

    // _route = new BreadcrumbTrack();
    // for (var i = 0; i < rawCoords.size() - 1; i++) {
    //   var lat = rawCoords[i][0];
    //   var lon = rawCoords[i][1];
    //   _route.addPointRaw(lat.toDouble(), lon.toDouble(), 0.0);
    // }
  }

  function trackRenderer() as BreadcrumbRenderer { return _breadcrumbRenderer; }
  function track() as BreadcrumbTrack { return _track; }
  function route() as BreadcrumbTrack or Null { return _route; }
  function newRoute() as BreadcrumbTrack {
    _route = new BreadcrumbTrack();
    return _route;
  }
}