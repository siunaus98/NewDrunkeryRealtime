# NewDrunkeryRealtime

Realtime prototype for the new direction of New Drunkery.

This project is intentionally separate from the old turn-based card prototype. The first goal is to validate the MVP loop:

- realtime movement and combat
- kitchen workflow
- order fulfillment
- defensive baseline food source
- blessings and relics as progression

## Local validation

Run the narrow Godot headless check with:

```bash
tools/validate_godot.sh
```

The script defaults to the Steam Godot executable on this machine and writes its log into `.godot_user_data/godot-validation.log`. If Godot is installed elsewhere, override it with:

```bash
GODOT_BIN="/path/to/Godot" tools/validate_godot.sh
```
