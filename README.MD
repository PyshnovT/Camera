<img src="Resources/example.gif">
<img src="Resources/icon-120.png">

**I am recreating Instagram-like filters using Core Image, Metal,
and ideas from functional programming.**

At the moment this app displays a simple Metal View rendering real time frames coming
from your camera. Frames go through the Core Image pipeline and processed by Noir Filter.
All work done on GPU.

## Plans

0. Render frames from an iPhone Camera in Metal View. [DONE]
1. Add UI to take photos and choose filters. [IN PROGRESS]
2. Write Core Image kernels for custom effects.
3. Add support for recording videos.

## Architecture

I am a big fan of [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) and I wanted to write a simple
Camera app using principles of functional programming for something that feels "imperative" (Camera device).
However, I did not import TCA and used my own simple structs (State, Action, Reducer/UseCase),
because I did not want to depend on a framework.

## Inspiration

1. [objc.io article on real-time image filtering with Core Image](https://www.objc.io/issues/23-video/core-image-video/)
2. [objc.io article on camera capture](https://www.objc.io/issues/21-camera-and-photos/camera-capture-on-ios/)
3. [This guy's awesome tutorial](https://betterprogramming.pub/using-cifilters-metal-to-make-a-custom-camera-in-ios-c76134993316)
4. [TCA](https://github.com/pointfreeco/swift-composable-architecture)
5. [A classic: Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)

