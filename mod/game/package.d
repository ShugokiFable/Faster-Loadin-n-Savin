
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module game;

public import game.target;


enum GameArchetype : ubyte
{
	ae,
	ae640,
	ae353,
	se,
	vr,
	gog,
	gog659,
}


enum GameArchetype targetedGameArchetype = __traits(getMember, GameArchetype, targetedGameTag);

