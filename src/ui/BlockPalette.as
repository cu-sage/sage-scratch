/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// BlockPalette.as
// John Maloney, August 2009
//
// A BlockPalette holds the blocks for the selected category.
// The mouse handling code detects when a Block's parent is a BlocksPalette and
// creates a copy of that block when it is dragged out of the palette.

package ui {

import blocks.blockList;
import blocks.latestBlock;

	import blocks.Block;
	import interpreter.Interpreter;
	import uiwidgets.*;
	import scratch.ScratchObj;
	import scratch.ScratchComment;

import flash.events.Event;


public class BlockPalette extends ScrollFrameContents {

	public const isBlockPalette:Boolean = true;
	public var hints:Hints = new Hints();

	public function BlockPalette():void {
		super();
		this.color = 0xE0E0E0;
	}

	override public function clear(scrollToOrigin:Boolean = true):void {
		var interp:Interpreter = Scratch.app.interp;
		var targetObj:ScratchObj = Scratch.app.viewedObj();
		while (numChildren > 0) {
			var b:Block = getChildAt(0) as Block;
			if (interp.isRunning(b, targetObj)) interp.toggleThread(b, targetObj);
			removeChildAt(0);
		}
		if (scrollToOrigin) x = y = 0;
	}

	public function handleDrop(obj:*):Boolean {

		trace("blockpalette.handledrop called");

		// Delete blocks and stacks dropped onto the palette.
		var c:ScratchComment = obj as ScratchComment;
		if (c) {
			c.x = c.y = 20; // position for undelete
			c.deleteComment();
			return true;
		}
		var b:Block = obj as Block;

		//yc2937 if block was dragged from scripts pane to palette, decrement points

		if (b) {

			if (Scratch.app.blockDraggedFrom == Scratch.K_DRAGGED_FROM_SCRIPTS_PANE) {
				obj.allBlocksDo(function(b:Block):void {
					trace ("dragged from scripts pane to palette: " + b.spec);
					// update latest block for hinting purposes (to account for block(s) being removed)
					if (blockList.length > 0) {
						blockList.pop();
						if (blockList.length > 0) {
							// delete all children from blockList as well
							var current:Block = b;
							while (current.nextBlock != null) {
								for (var i:int=0; i < blockList.length; i++) {
									if (blockList[i] == current) {
										blockList.splice(i, 1);
									}
								}
								current = current.nextBlock;
							}

							latestBlock = blockList[blockList.length - 1];

							trace("LATEST BLOCK: " + latestBlock.op);
							var blocksToPrint:Array = [];
							for each (var block:Block in blockList) {
								blocksToPrint.push(block.op);
							}
							trace("BLOCK LIST:    " + String(blocksToPrint));
						}
						else { // no more blocks present to use for hinting
							latestBlock = null;
						}
						if (latestBlock) {
							// see if a hint can be issued based on the current latest block
							var latestHint:Hints = new Hints(latestBlock.op);
							addChild(latestHint);
							hints.log('hinting from BlockPalette')
							latestHint.checkHint();
						}
						var hintRules:Array = hints.getRules();
						var hintBlocks:Array = hints.getRuleBlocks();
						hints.log('rules from BlockPalette: ' + hintBlocks);
						if (hintBlocks.indexOf(this.op) >= 0) {
							hints.log("HINTING OPPORTUNITY FOUND!!!!");
						}
					}
					//sm4241 - parsons logic
					//Scratch.app.parsonsLogic();
					//Scratch.app.decrementPoints(b.pointValue);
				});
			}

			trace("blockpalette.handledrop resetting flag ");

			Scratch.app.blockDraggedFrom = Scratch.K_NOT_DRAGGED_FROM_PALETTE_OR_SCRIPTS_PANE;

			return b.deleteStack();;

		}
		trace("blockpalette.handledrop resetting flag");

		Scratch.app.blockDraggedFrom = Scratch.K_NOT_DRAGGED_FROM_PALETTE_OR_SCRIPTS_PANE;

		return false;
	}

	public static function strings():Array {
		return ['Cannot Delete', 'To delete a block definition, first remove all uses of the block.'];
	}

}}
