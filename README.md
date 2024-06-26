# percept-ios

## Setup

### Using SPM

Add Percept as a dependency in your Package.swift file

```swift
dependencies: [
  .package(url: "https://github.com/udaan-com/percept-ios.git", from: "1.0.0")
],
```

### Using CocoaPods

Add it to your podfile

```
pod "Percept", "~> 1.0.0"
```

## Usage

```swift
import Percept

let config = PerceptConfig(apiKey: apiKey)
Percept.shared.setup(config)
```

### Change the default configuration

```swift
let config = PerceptConfig(apiKey: apiKey)
config.captureAppLifecycleEvents = false
config.debug = true
// .. and more
```

### Capture an event

```swift
Percept.shared.capture("Add To Cart", properties: ["item_name": "product name"])
```

### Set user id

```swift
Percept.shared.setUserId("testUser", withPerceptUserProps: [PerceptUserProperty.NAME: "John Doe"], additionalProps: ["isVerified": false])
```

We expose some default user property keys in `PerceptUserProperty`. Please use them as this helps in standarization and usage in the Engage feature provided by Percept.

You can set user properties post setting user id too by calling `setCurrentUserProperties` method.

```swift
Percept.shared.setCurrentUserProperties(withPerceptUserProps: [PerceptUserProperty.NAME: "John Doe"], additionalProps: ["isVerified": false])
```

### Set global properties

```swift
Percept.shared.setGlobalProperties(["tenant": "percept"])
```

### Get global properties

```swift
Percept.shared.getGlobalProperties(["tenant": "percept"])
```

### Remove global property

```swift
Percept.shared.removeGlobalProperty("tenant")
```

### Clear

This will clear all user info and cached data. Call clear function on logout to delete all user related information

```swift
Percept.shared.clear()
```

### Close the SDK

```swift
Percept.shared.close()
```
