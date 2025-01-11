Here's how to use the input library with examples:



The input library provides a complete, reusable text input system with all the features from your chat client. Key features include:

1. Full text editing capabilities:
   - Cursor movement with arrow keys
   - Word navigation with Ctrl+arrows
   - Selection with Shift+arrows
   - Copy/paste with Ctrl+C/V
   - Undo/redo with Ctrl+Z/Y

2. Advanced input handling:
   - UTF-8 support for international characters
   - Proper key repeat behavior
   - Caps lock support
   - Input history with up/down arrows
   - Protected prefix option (e.g. for chat commands)

3. Customization options:
   - Maximum text length
   - Protected prefix
   - Minimum cursor position
   - Callbacks for changes, submit, and cancel

4. Selection features:
   - Text selection
   - Cut/copy/paste
   - Select all (Ctrl+A)

5. History management:
   - Input history tracking
   - Navigation through history
   - History size limit

To use the library in your own projects, simply:
1. Copy the library files to your project
2. Create an instance with desired configuration
3. Call update() in your input handling
4. Use the provided methods to access/modify state

The example shows how to integrate it into a basic chat system, but it can be used for any text input needs in your scripts.
