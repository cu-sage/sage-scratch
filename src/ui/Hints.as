/**
 * Created by AliSawyer on 22/04/2017.
 */

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

// Hints.as
// Allison Sawyer, April 2017
//

package ui {

import blocks.Block;
import blocks.Block;
import blocks.BlockIO;

import flash.display.DisplayObject;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import flash.geom.Rectangle;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.utils.Timer;
import flash.utils.getQualifiedClassName;

import org.osmf.events.TimeEvent;

import scratch.PaletteBuilder;

import uiwidgets.*;
import flash.geom.Point;

public class Hints extends ScrollFrameContents {

	private static var rulesFile:String;
	private static var rules:Array;
	private static var leftCol:Array;

	private var toHintOn:String; // left-column block (used to generate hint)
	private var pb:PaletteBuilder = Scratch.app.paletteBuilder;
	private static var catToShake:PaletteSelectorItem;

	private static var blocksToSuggest:Array = [];
	// 5-second delay before category hint is issued (if available)
	private var categoryTimer:Timer = new Timer(5000);
	// 5-second delay before block hint is issued (if available)
	private var blockTimer:Timer = new Timer(5000);

	public function Hints(opStr:String = ''):void {
		rulesFile = '';
		this.toHintOn = opStr;
	}

	public function getRules():Array {
		return rules;
	}

	public function getRuleBlocks():Array {
		return leftCol;
	}

	public function getRulesFile():void {
		//var h:HintsFlashVar = new HintsFlashVar();
		try {
			rulesFile = root.loaderInfo.parameters.gspResults;
			// open rules file
			var myTextLoader:URLLoader = new URLLoader();
			// set event listener to detect when file is done loading
			myTextLoader.addEventListener(Event.COMPLETE, onLoaded);
			function onLoaded(e:Event):void {
				var rulesData:Array = e.target.data.split(/\n/);
				rules = extractRules(rulesData);
				leftCol = getLeftCol(rules);
			}
			myTextLoader.load(new URLRequest('gsprules'));
		} catch (e:Error) {
			log(String(e));
		}
	}

	private function extractRules(data:Array):Array {
		var allRules:Array = [];
		for each (var line:String in data) {
			// find 2 block names that make up a rule in form <block1> <block2>
			var pattern:RegExp = /<([^>]+)>  <([^>]+)>/g;
			var rule:Array = line.match(pattern);
			// if more than one, only keep first one
			if (rule && rule[0] && rule[0] != '' && allRules.indexOf(rule[0]) < 0) {
				allRules.push(rule[0]);
			}
		}
		return allRules;
	}

	private function getLeftCol(rules:Array):Array {
		var left:Array = [];
		for each (var r:String in rules) {
			var leftAndRight:Array = r.split('  ');
			var toAdd:String = leftAndRight[0];
			// strip angle brackets
			toAdd = strip(toAdd);
			left.push(toAdd);
		}
		return left;
	}

	public function getRightCol(allRules:Array, blockFound:String):Array {
		var rightBlocks:Array = [];
		for each (var r:String in allRules) {
			var leftAndRight:Array = r.split('  ');
			if (strip(leftAndRight[0]) == blockFound && rightBlocks.indexOf(blockFound) < 0) {
				rightBlocks.push(strip(leftAndRight[1]));
			}
		}
		log('rightBlocks: ' + rightBlocks)
		return rightBlocks;
	}

	// strip angle brackets
	private function strip(str:String):String {
		return str.substring(1, str.length - 1);
	}

	public function checkHint() {
		if (leftCol.indexOf(this.toHintOn) >= 0) {
			// get blocks that should be suggested (as hints)
			blocksToSuggest = getRightCol(rules, this.toHintOn);
			if (blocksToSuggest) {
				// set timer and then call shake event
				startCategoryTimer();
			}
		}
	}

	private function startCategoryTimer():void {
		categoryTimer.addEventListener(TimerEvent.TIMER, afterCategoryTimer);
		categoryTimer.start();
	}

	private function afterCategoryTimer(event:TimerEvent):void {
		categoryTimer.removeEventListener(TimerEvent.TIMER, afterCategoryTimer);
		// after 5 seconds have passed, issue hint
		shakeCategory();
	}

	private function shakeCategory():void {
		//if (blocksToSuggest.length > 0) {
		for each (var opStr:String in blocksToSuggest) {
			var currentCategory:int = Scratch.app.paletteBuilder.getCurrentCategory();
			// get category of block to hint
			var suggBlockInfo:Array = BlockIO.specForCmd([opStr], " ");
			var suggCategory:int = suggBlockInfo[2];

			// hint needs to be generated in a different palette category
			if (currentCategory != suggCategory) {
				var ps:PaletteSelector = Scratch.app.getScriptsPart().getPaletteSelector();
				// shake category of suggested block
				//var catToShake:PaletteSelectorItem = ps.hintSelect(suggCategory);
				catToShake = ps.hintSelect(suggCategory);
				catToShake.addEventListener(MouseEvent.CLICK, startBlockTimer);
			}
		}
	}

	private function startBlockTimer(evt:MouseEvent):void {
		blockTimer.addEventListener(TimerEvent.TIMER, afterBlockTimer);
		blockTimer.start();
		catToShake.removeEventListener(MouseEvent.CLICK, startBlockTimer);
	}

	private function afterBlockTimer(event:TimerEvent):void {
		blockTimer.removeEventListener(TimerEvent.TIMER, afterBlockTimer);
		// after 5 seconds have passed, issue hint
		shakeBlock();
	}

	/* If hint has to be issued in a category different from the current one,
	 *  wait until the user clicks on the appropriate category for the hint and then
	 *  shake the relevant block. */
	private function shakeBlock() {
		//if (blocksToSuggest.length > 0) { // should always be true
		log('blocksToSuggest: ' + blocksToSuggest);
		for each (var opStr:String in blocksToSuggest) {
			/*
			//var opStr:String = blocksToSuggest[0];
			//var blockHint:Hints = new Hints();
			//var blockToShake:Block = Scratch.app.paletteBuilder.getBlockByOp(opStr);
			if (blockToShake) {
				log('toShake: ' + blockToShake.op);
				//blockHint.initShake(blockToShake);
				blockToShake.hintSelect();
			}
			*/
			//var b:Block = new Block();
			//var b:Block = this.parent as Block;
			//if (b) b.hintSelect(opStr);
			//else log('PARENT IS NULL')
			var blockToShake:Block = pb.getBlockByOp(opStr);
			if (blockToShake) {
				log('blockToShake op: ' + blockToShake.op);
				var shaker:Shaker = new Shaker(blockToShake);
				//initShake(blockToShake);
				shaker.initShake();
			}
		}
	}

	public function log(msg:String, caller:Object = null):void {
		var str:String = "";
		if(caller){
			str = getQualifiedClassName(caller);
			str += ":: ";
		}
		str += msg;
		trace(str);
		if(ExternalInterface.available){
			ExternalInterface.call("console.log", str);
		}
	}
}}

