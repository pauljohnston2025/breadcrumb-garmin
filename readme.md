A garmin watch datafield that shows a breadcrumb trail. For watches that do not support breadcrumb navigation out of the box.

Donations are always welcome, but not required: https://www.paypal.com/paypalme/pauljohnston2025

Information on all the settings can be found in [Settings](settings.md)  
note: Map support is disabled by default, but can be turned on in app settings, this is because map tile loading is memory intensive and may cause crashes on some devices. You must set `Tile Cache Size` if using maps to avoid crashes.    
Companion app can be found at [Companion App](https://github.com/pauljohnston2025/breadcrumb-mobile.git)  
[Companion App Releases](https://github.com/pauljohnston2025/breadcrumb-mobile/releases/latest)

---

There are several different apps/datafields on the connect-iq store all with similar breadcrumb functionality 

Each one has its own repository mirror (git push --mirror https://github.com/pauljohnston2025/XXX.git).  
I could use monkey barrels to share common code, but barrels have a memory overhead, and I only expect 1 of these apps/datafields to be installed at a time.  
I also expect the merge conflicts will be easier to deal with rather than a whole heap of (:excludeAnnotations)  
Doing it this way also means each repo has 0 dependents and is fully stand-alone.   
There are multiple Datafield app types, so that users can install 2 alongside eachother if they want. eg. have both the BreadcrumbDataField and LWBreadcrumbDataField enabled at the same time so that if BreadcrumbDataField crashes from OOM or some high usage map task we can still navigate the planned route using LWBreadcrumbDataField.  If a user has 2 installed it would be good practice to disable alerts on one of the datafields, or you will get 2 independent alert for each 'off track' etc.  

The original project is https://github.com/pauljohnston2025/breadcrumb-garmin it contains the main datafield with all features on supported watches.

note: Some older devices will not support all of the features (eg. routes/ device settings) This is a garmin limitation as those devices (<3.2.0 api) do not support phone app messages for datafields.

The current mirrors are: 

* [BreadcrumbDataField](https://github.com/pauljohnston2025/breadcrumb-garmin) 
  * [Garmin Store](https://apps.garmin.com/apps/99d7ebcc-3586-4dbd-8684-08b5ce4ddd80)
  * Type - DataField
  * Full breadcrumb trail with map tile support
* [BreadcrumbApp](https://github.com/pauljohnston2025/breadcrumb-garmin-app)
  * [Upstream mirror - BreadcrumbDataField](https://github.com/pauljohnston2025/breadcrumb-garmin)
  * [Garmin Store](https://apps.garmin.com/apps/40e128d2-db98-41d1-b5a9-624a725e6e68)
  * Type - App
  * An app instead of a datafield
  * Full breadcrumb trail with map tile support
  * Adds more control
    * Support for non-touch screen devices, as it can handle button press events
    * Touch screens can drag the map around to pan
  * Supports more features on more devices (the app has larger memory limits than a datafield)
* [BreadcrumbAppGlance](https://github.com/pauljohnston2025/breadcrumb-garmin-app-glance)
  * [Upstream mirror - BreadcrumbApp](https://github.com/pauljohnston2025/breadcrumb-garmin-app)
  * [Garmin Store](https://apps.garmin.com/apps/54ea0621-918f-40ec-864e-d3fc7eb6ecbf)
  * Type - App
  * Same as BreadcrumbApp but removed activity recording (this is so it can be opened from a glance view whilst recording using a garmin native activity)
* [LWBreadcrumbDataField](https://github.com/pauljohnston2025/breadcrumb-garmin-light-weight)
  * [Upstream mirror - BreadcrumbDataField](https://github.com/pauljohnston2025/breadcrumb-garmin)
  * [Garmin Store](https://apps.garmin.com/apps/3506adc5-7098-42ff-8c3f-601de1184aa5)
  * Type - DataField
  * Full breadcrumb trail (no map tile support)
* [ULBreadcrumbDataField](https://github.com/pauljohnston2025/breadcrumb-garmin-ultra-light)
  * [Upstream mirror - LWBreadcrumbDataField](https://github.com/pauljohnston2025/breadcrumb-garmin-light-weight)
  * [Garmin Store](https://apps.garmin.com/apps/fc5a0149-347a-4c39-aaf2-735eddd7b7bd)
  * Type - DataField
  * Limited breadcrumb trail (no map support, no alerts)
  * This is the lightest weight datafield and is supported on more devices, it is restricted to 1 route and 1 track and alot of customisation is missing

The companion app supports all of the watch apps, but the watch app must be selected in the companion app settings.


---

# Bug Reports

To aid in the fastest resolution, please include.

- Some screenshots of the issue, and possibly a recording
- A reproduction case of exactly how to reproduce the issue
- What you expected to happen
- The settings that you had enabled/disabled (a full screenshot of all the settings is best)

Please ensure any images/recordings do not contain any identifying information, such as your current location.

If the watch app encounters a crash (connect iq symbol displayed), you should also include the crash report. This can be obtained by:

* Connect the watch to a computer
* Open the contents of the watch and navigate to  `<watch>\Internal Storage\GARMIN\APPS\LOGS`
* Copy any log files, usually it is called CIQ_LOG.LOG, but may be called CIQ_LOG.BAK

You can also manually add a text file `BreadcrumbDataField.TXT` to the log directory (before the crash), and any app logs will be printed there. Please also include this log file.

---

# Development

Must port forward both adb and the tile server for the simulator to be able to fetch tiles from the companion app

* adb forward tcp:8080 tcp:8080
* adb forward tcp:7381 tcp:7381

To merge in the upstream do

```
cd path/to/mirrored/repo  eg. breadcrumb-garmin-light-weight
git remote add old-repo https://github.com/pauljohnston2025/breadcrumb-garmin.git
git fetch old-repo --no-tags
git merge old-repo/master
```

---

# Garmin Iq Store Content

Can be used without the companion app, but will only show current track.
Use the companion app to add a route that you can follow.

Intended for use with round watches, but will work on others (might not look the best though).  
Some watches/devices with touch support will be able switch between elevation and track view during activity.

Target User: Hikers, backpackers, cyclists, trail runners, and outdoor enthusiasts seeking a flexible navigation tool for their Garmin watches. Especially valuable for users with Garmin devices that do not have built-in map support. Suitable for both on- and off-grid exploration, with customizable maps and route following capabilities.

Key Features:

Breadcrumb Trail Navigation: Displays a route as a breadcrumb trail overlaid on a map, allowing users to easily follow the intended path. Brings map-based navigation to Garmin devices that do not have native map support.  
Map Tile Loading (Online): Supports any tile server that uses EPSG:3857 image tiles.  
Map Tile Loading (Offline): Loads pre-cached tile data from the companion app.  
Off-Track Alerts (needs to be enbaled in garmins setting menu, see below): Notifies the user when they deviate from the planned route.  
Elevation Overview: Shows an elevation profile of the route, allowing users to anticipate upcoming climbs and descents.  
Routing (companion app required): Users can import routes from Google Maps or GPX files using the companion app.  
Customizable Settings: Fully customizable via the watch or Connect IQ settings. No companion app required for basic functionality.  
Breadcrumb-Only Mode: (Optional) A simplified display mode showing only the breadcrumb trail, without the underlying map tiles, for increased battery life on devices with limited screen resolution or memory.

Companion app:
The companion app is available on my github: https://github.com/pauljohnston2025/breadcrumb-mobile.git  
While all settings can be configured directly on the watch or through Connect IQ settings, the companion app unlocks powerful features such as offline map support via Bluetooth transfer and route loading. Currently, the companion app is only available on Android, but contributions from iOS developers are highly welcomed to expand platform support and bring these functionalities to a wider audience.

This is a datafield, not a full fledged app, it runs in the context of native activity.  
The datafield is expected to be used to cover the full available area of a round watchface.    
It will still work with non-round devices or partial layouts, but the full feature set of the ui will not be possible due to the limited space.  

To add datafield to a native app:

- Open the app (eg. running), you do not have to start the activity, just open it.
- Long press to open settings (or use the touchscreen to press settings)
- Navigate to Data Screens
- Select screen
- Choose layout - recommended full screen layout
- Edit data fields - choose the 'BreadCrumbDataField' from the 'ConnectIQ Fields' menu

For the venu range: https://support.garmin.com/en-AU/?faq=gyywAozBuAAGlvfzvR9VZ8&identifier=707572&searchQuery=data%20field&tab=topics  
A more thorough explanation for a different app can be found at: https://support.garmin.com/en-AU/?faq=3HkHX1wT6U7TeNB7YHfiT7&identifier=707572&searchQuery=data%20field&tab=topics

---

# Known Issues

Some screens appear to have an offset applied to the [dc](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html), that I cannot find a way to correct. Sometimes this offset occurs on my own physical device, and other times there is no offset. If anyone knows how to solve this, please let me know. I believe this is an issue with garmins datafield obscurity, since you can have the datafield take up only part of the screen. The problem still occurs when the datafield takes up the whole screen though (I think garmin reserves certain areas of the screen for their own ui components). Note this clipping may also be noticed on different parts of the screen if buffered map rotations are enabled, since everything drawn to the dc is offset.

Simplest reproduction example, it appears the device context for drawing is already offset (but only sometimes).

```
function onUpdate(dc as Dc) as Void {
    dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
    dc.clear();
}
```

The white areas in the bellow images show the issue.

![](images/screenoffsetvenu2.png)
![](images/screenoffsetvenu3.png)
![](images/screenoffsetvenu3s.png)

---

# Map Tiles

Powered by Esri: https://www.esri.com  
OpenStreetMap: https://openstreetmap.org/copyright  
OpenTopoMap: https://opentopomap.org/about  
Google: https://cloud.google.com/maps-platform/terms https://policies.google.com/privacy  
Carto: https://carto.com/attribution  
Stadia: &copy; <a href="https://stadiamaps.com/" target="_blank">Stadia Maps</a> &copy; <a href="https://openmaptiles.org/" target="_blank">OpenMapTiles</a> &copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>  
Mapy: https://mapy.com/ https://api.mapy.com/copyright

---

# Licencing

Attribution-NonCommercial-ShareAlike 4.0 International: https://creativecommons.org/licenses/by-nc-sa/4.0/  

---
