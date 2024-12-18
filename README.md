

# InnertiaStopper

## Overview
**Challenge**: 
Do you have an external mouse and let the scroll wheel spinning? This is super useful to quickly scroll through a large document or web page. But if you then move the mouse to a different context it continues scrolling. This is often undesirable (e.g. the it starts scrolling through the tabs of the browser or another document.)

**Solution**: This small app checks the scroll wheel and mouse position in the background. If the scroll wheel is spinning and you move the mouse pointer, the scrolling slows down and eventually stops completely (if you move the mouse far). you then can only restart scrolling with the wheel once, it has completely stopped rotating for 0.5 sec.

## Installation
Best you build it directly in Xcode. The app requires special  accessibility permission, as it monitors low level mouse events. It will ask the first time you use it.
Note: If you make changes to the code and rebuild it, you will need to delete the permissions and then allow again.

- [Contact](#contact)

<!--stackedit_data:
eyJoaXN0b3J5IjpbMTk1NTQxNTY5LC0xNzQyMTMxNTVdfQ==
-->