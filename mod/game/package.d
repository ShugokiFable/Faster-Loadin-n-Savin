
/+ SPDX-LICENSE-IDENTIFIER: 0BSD +/

module game;

public import game.target;


enum GameArchetype : ubyte
{
	ae = 0,
	se = 1,
	vr = 2,
	gog = 3,
}


enum GameArchetype targetedGameArchetype = __traits(getMember, GameArchetype, targetedGameTag);

