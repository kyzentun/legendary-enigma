# legendary-enigma
Galaga recreation with editable campaigns

As of right now, the game is not really playable.  The foundation must be
laid before the house can be built.

# Setup
Install Love2D.  Build a love package, or point love to this folder.

# Controls

The mouse can be used in menus, but not in gameplay.  Gameplay uses keyboard
keys because mouse movement bound by a top speed feels crippled, and mouse
movement without top speed is too much of an advantage.

Firing is continuous as long as the fire key is held.

### Pregame / Prize Info Screen
* "escape" -> Exit game.
* "1" -> Start gameplay test mode.
* "k" -> Reconfigure key bindings.
* "m" -> Start menu system test mode.

### Gameplay
#### (unpaused)
* "escape" -> Pause game, brings up pause menu
* arrow keys -> Move player ship around.
* "space" -> Fire.

Other controls can be learned by reading the menu in the key config screen.
Many of them exist for debugging and will be removed later.

# Origin story
As a beginning programmer in 2002, I was introduced to XGalaga.  I spent many
months learning C and expanding XGalaga with new weapons and prizes.

This project is a recreation of that modified version of XGalaga, with more
improvements.

## Graphics from XGalaga
Most of the graphics were ripped from XGalaga.  The prize images for the
prizes I added in 2002 were made by me.

Graphics I made:
* pr_blizzard1, pr_blizzard2
* pr_<bonus, neutral, malus>_<attractor, repulsor, destructor>
* pr_<cluster, tree, wave>_<sing, doub, trip>
* pr_<dec, inc>_<cannon_spread, prize_speed, torp_speed>
* pr_wrap

Love2D is used for graphics and input.
