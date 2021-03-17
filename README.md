# Defold Screen Manager
Defold Screen Manager (dscreen) 0.1.0 provides a game state management system in a Defold game engine project.

An [example project](https://github.com/klaytonkowalski/defold-screen-manager/tree/main/example) is available if you need additional help with configuration.  
Visit [my website](https://klaytonkowalski.github.io/html/extensions.html#dta) to see an animated gif of the example project.

Please click the "Star" button on GitHub if you find this asset to be useful!

![alt text](https://github.com/klaytonkowalski/defold-screen-manager/blob/main/assets/thumbnail.png?raw=true)

## Installation
To install dscreen into your project, add one of the following links to your `game.project` dependencies:
  - https://github.com/klaytonkowalski/defold-screen-manager/archive/main.zip
  - URL of a [specific release](https://github.com/klaytonkowalski/defold-screen-manager/releases)

## Configuration
Screen managers are impactful libraries in part because they require you to structure your project according to their expectations. In order to use dscreen, your project should consist of a main bootstrap collection, which contains all other game screens as objects with a collection proxy inside of them. For example:

```
Main (Collection)  
    Main (Game Object)  
        Main (Script)  
    Title Screen (Game Object)  
        Title Screen (Collection Proxy)  
    Options Screen (Game Object)  
        Options Screen (Collection Proxy)  
    Game World Screen (Game Object)  
        Game World Screen (Collection Proxy)  
    Pause Screen (Game Object)  
        Pause Screen (Collection Proxy)  
    Inventory Screen (Game Object)  
        Inventory Screen (Collection Proxy)
```

The "Main (Script)" is where you will configure dscreen. Import the dscreen module into your main script like so:  
`local dscreen = require "dscreen.dscreen"`

In order for dscreen to recognize each collection proxy as a screen, you must register each of them like so:

```
function init(self)
	  dscreen.register_screen(hash("title"), dscreen.screen_types.basic, msg.url("main", "/title", "collectionproxy"), msg.url("title", "/gui", "gui"))
	  dscreen.register_screen(hash("game"), dscreen.screen_types.basic, msg.url("main", "/game", "collectionproxy"), msg.url("game", "/gui", "gui"))
	  dscreen.register_screen(hash("pause"), dscreen.screen_types.pause, msg.url("main", "/pause", "collectionproxy"), msg.url("pause", "/gui", "gui"))
	  dscreen.register_screen(hash("options"), dscreen.screen_types.pause, msg.url("main", "/options", "collectionproxy"), msg.url("options", "/gui", "gui"))
	  dscreen.register_screen(hash("inventory"), dscreen.screen_types.toolbar, msg.url("main", "/inventory", "collectionproxy"), msg.url("inventory", "/gui", "gui"))
	  dscreen.push_screen(hash("title"))
end

function on_message(self, message_id, message, sender)
	  dscreen.on_message(message_id, message, sender)
end
```

In the example above, five screens were registered using the `dscreen.register_screen()` function:  
1. Title Screen
2. Game Screen
3. Pause Screen
4. Options Screen
5. Inventory Screen

Each screen is registered along with its screen type, collection proxy URL, and script URL. All screen types and their explanations can be found in the `dscreen.screen_types` [table](#dscreenscreen_types). In this example, the inventory screen is set to `dscreen.screen_types.toolbar` so that it can be toggled on and off while the player is roaming around the game world.

The `dscreen.push_screen()` function is then called, with an argument of `hash("title")`. This ensures that the first screen the player sees when loading the game is the title screen.

It is important to remember to always include the `dscreen.on_message()` function inside of your script's `on_message()` function. Each of your screens must contain a script that handles these messages. Defold's engine utilizes the `hash("proxy_loaded")` and `hash("proxy_unloaded")` messages to alert the developer of collection proxy status.

Registered screen are loaded the first time they are pushed to the stack. If they are eventually popped off the stack, they are *not* unloaded--only disabled and finalized. Use the `dscreen.unload_screen()` to fully unload a screen. Please read this function's [documentation](#dscreenunload_screenscreen_id) to learn about when to unload a screen.

## API: Properties

### dscreen.screen_types

Table for specifying behavior properties of a screen in the `register_screen()` function:

```
dscreen.screen_types = {
    basic = 1,
    pause = 2,
    toolbar = 3
}
```

1. `basic`: Disables and finalizes all active screens on the stack. *Use case examples: title screen, game world screen.*
2. `pause`: Pauses all active screens on the stack. *Use case examples: pause screen, alert dialog box screen.*
3. `toolbar`: No effect on other screens. *Use case examples: popup inventory screen, information dialog box screen.*

### dscreen.msg

Table for referencing message posted to your script's `on_message()` function:

```
dscreen.msg = {
    pushed_in = hash("pushed_in"),
    pushed_out = hash("pushed_out"),
    popped_in = hash("popped_in"),
    popped_out = hash("popped_out")
}
```

1. `pushed_in`: Posted when this screen is pushed to the top of the stack.
2. `pushed_out`: Posted when this screen is no longer the top of the stack due to pushing a different screen.
3. `popped_in`: Posted when this screen becomes the top of the stack due to popping a different screen.
4. `popped_out`: Posted when this screen is popped from the stack.

## API: Functions

### dscreen.register_screen(screen_id, screen_type, proxy_url, script_url)

Registers a screen.

#### Parameters
1. `screen_id`: Hashed collection name.
2. `screen_type`: Behavior properties of this screen, referenced from the `dscreen.screen_types` [table](#dscreenscreen_types).
3. `proxy_url`: `msg.url()` to this collection's `#collectionproxy` component.
4. `script_url`: `msg.url()` to the script that should receive messages.

---

### dscreen.unregister_screen(screen_id)

Unregisters a screen. Not necessary, but provided for completeness.

#### Parameters
1. `screen_id`: Hashed collection name.

---

### dscreen.push_screen(screen_id)

Pushes a screen to the top of the stack. Fails if the screen is already on the stack.

#### Parameters
1. `screen_id`: Hashed collection name.

---

### dscreen.pop_screen(count)

Pops screens off the top of the stack.

#### Parameters
1. `count`: Number of screens to pop. Omitting this argument is equivalent to calling `dscreen.pop_screen(1)`.

---

### dscreen.unload_screen(screen_id)

Unloads a screen. Fails if the screen currently resides on the stack.

**Note:** It is recommended that a screen is only unloaded if it is no longer relevant to the current functioning of your game. Loading and unloading collection proxies takes time and may result in slight screen loading delays.

Example of when to potentially unload a screen:

*Current screen = GameWorldScreen*  
GameWorldScreen --> PauseScreen, InventoryScreen  
PauseScreen --> OptionsScreen, TitleScreen  
TitleScreen --> OptionsScreen, GameWorldScreen  

Since there is no way to traverse from GameWorldScreen to TitleScreen, it may be a good idea to `dscreen.unload(TitleScreen)` after GameWorldScreen is loaded and displayed.

#### Parameters
1. `screen_id`: Hashed collection name.

---

### dscreen.set_screen_data(screen_id, data)

Assign custom data to a screen for later reference.

#### Parameters
1. `screen_id`: Hashed collection name.
2. `data`: Table of custom data.

---

### dscreen.get_screen_data(screen_id)

Get custom screen data.

#### Parameters
1. `screen_id`: Hashed collection name.

---

### dscreen.on_message(message_id, message, sender)

Handles engine collectionproxy messages. Must be called in the `on_message()` function of the script you passed to the `register_screen()` function.

#### Parameters

Parameters must be forwarded from your script's `on_message()` function.
