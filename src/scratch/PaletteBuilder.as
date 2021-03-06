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

// PaletteBuilder.as
// John Maloney, September 2010
//
// PaletteBuilder generates the contents of the blocks palette for a given
// category, including the blocks, buttons, and watcher toggle boxes.

package scratch {
	import flash.display.*;
	import flash.events.MouseEvent;
	import flash.events.Event;
	import flash.net.*;
	import flash.text.*;
	import flash.utils.*;
	import blocks.*;
	import extensions.*;
	import flash.events.TextEvent;
	import util.*;


import org.apache.flex.collections.ArrayList;

import ui.media.MediaLibrary;

	import ui.ProcedureSpecEditor;
	import ui.parts.UIPart;
	import uiwidgets.*;
	import translation.Translator;

public class PaletteBuilder {

	private var sageIncludedBlocks:Dictionary;

	protected var app:Scratch;
	protected var nextY:int;

	//public var comments:String;
	private var currentCategory:int;

	private var parsonsBlock:ArrayList= new ArrayList();
	private var question:String="";
	private var hint:String="";
	private var hintCounter:int=0;
	private var peerFeedbackCounter:int=0; 

	private var DEFAULT_TIME:String="10:00";
	private var inputTime:String=DEFAULT_TIME;

	// store all blocks for use in hinting
	private var paletteBlocks:Array = new Array();


	public function PaletteBuilder(app:Scratch) {
		this.app = app;
		currentCategory=1;
		initSageIncludedBlocks();
	}

	public static function strings():Array {
		return [
			'Stage selected:', 'No motion blocks',
			'Make a Block', 'Make a List', 'Make a Variable',
			'New List', 'List name', 'New Variable', 'Variable name',
			'New Block', 'Add an Extension'];
	}
	
	public function getSageIncludedBlocks():Dictionary {
		return sageIncludedBlocks;
	}
	
	public function setSageIncludedBlocks(included:Dictionary):void {
		sageIncludedBlocks = included;
	}
	
	public function resetSageIncludedBlocks():void {
		initSageIncludedBlocks();
	}
	
	public function updateBlocks():void {
		showBlocksForCategory(currentCategory, false);
		app.getViewedObject().updateScriptsAfterTranslation(); // resest ScriptsPane
	}
	
	public function updateBlock(spec:String, included:Boolean):void {
		if (spec == 'when Stage clicked') spec = 'whenClicked'; // special case
		sageIncludedBlocks[spec] = included;
		updateBlocks();
	}
	
	public function paletteIncluded(category:int):Boolean {
		return app.scriptsPart.getSagePalettes()[category];
	}
	
	public function blockIncluded(block:Block):Boolean {
		return blockLabelCategoryIncluded(block.spec, getBlockCategory(block.spec));
	}
	
	public function getBlockCategory(label:String):int {
		if (label == 'when Stage clicked') label = 'whenClicked'; // special case
		var category:int = -1;
		for each (var spec:Array in Specs.commands) {
			if ((spec.length > 3) && (spec[0] == label))
			{
				category = spec[2];
				if(category > 100)
					category -= 100;
				return category;
			}
		}
		return category; // invalid state, category should be found
	}
	
	public function blockLabelIncluded(label:String):Boolean {
		return blockLabelCategoryIncluded(label, getBlockCategory(label));
	}
	
	public function blockLabelCategoryIncluded(label:String, category:int):Boolean {
		if(category > 100)
			category -= 100;
		return app.scriptsPart.getSagePalettes()[category] && sageIncludedBlocks[label];
	}

	//sm4241 - creating dictionary of blocks included in parsons palette
	public function getParsonsIncludedBlocks():Array {
		var parsonsBlockArr:Array = [];
		if (parsonsBlock.length > 0) {
			for (var i:int=0; i<parsonsBlock.length; i++) {
				var currDict:Dictionary = new Dictionary();
				var pb:Block = Block (parsonsBlock.getItemAt(i));
				currDict['spec'] = pb.spec;
				currDict['type'] = pb.type;
				currDict['color'] = pb.base.color;
				currDict['cmd'] = pb.op;
				parsonsBlockArr.push(currDict);
			}

		}
		return parsonsBlockArr;
	}

	public function setParsonsIncludedBlocks(parsons:Array):void {
        if (parsons != null) {
            parsonsBlock = new ArrayList();
			if (parsons.length > 0) {
				for (var i:int = 0; i < parsons.length; i++) {
					var newBlock:Block = new Block(parsons[i]['spec'], parsons[i]['type'], parsons[i]['color'], parsons[i]['cmd']);
					parsonsBlock.addItem(newBlock);
				}
			}
		}
		updateCheckboxes();
	}

	public function getQuestion():String {
		return question;
	}

	public function setQuestion(q:String):void {
		if(q==null){
			question="None";
		}else{
			question = q;
		}

	}

	public function getHint():String {
		return hint;
	}

	public function setHint(h:String):void {
		if(h==null){
			hint="None";
		}else{
			hint = h;
		}
	}

	public function getHintCount():int {
		return hintCounter;
	}

	public function getPeerFeedbackCount():int {
		return peerFeedbackCounter;
	}

    public function getInputTime():String {
        return inputTime;
    }

    public function getInputTimeInSeconds():int {
        var timeString: String = getInputTime();
        var arr:Array = timeString.replace(/^\s+|\s+$/g, '').split(":");
        var min:Number = Number(arr[0]);
        var sec:Number = Number(arr[1]);
        var totalTime:Number = min * 60 + sec;

        return totalTime;
    }


	public function showBlocksForCategory(selectedCategory:int, scrollToOrigin:Boolean, shiftKey:Boolean = false):void {
		if (app.palette == null) return;
		currentCategory = selectedCategory;
		app.palette.clear(scrollToOrigin);
		nextY = 7;

		if (selectedCategory == Specs.dataCategory) return showDataCategory();
		if (selectedCategory == Specs.myBlocksCategory) return showMyBlocksPalette(shiftKey);

		//sm4241
		if (selectedCategory == Specs.parsonsCategory) return showParsonsPalette();

		var catName:String = Specs.categories[selectedCategory][1];
		var catColor:int = Specs.blockColor(selectedCategory);
		if (app.viewedObj() && app.viewedObj().isStage) {
			// The stage has different blocks for some categories:
			var stageSpecific:Array = ['Control', 'Looks', 'Motion', 'Pen', 'Sensing'];
			if (stageSpecific.indexOf(catName) != -1) selectedCategory += 100;
			if (catName == 'Motion') {
				addItem(makeLabel(Translator.map('Stage selected:')));
				nextY -= 6;
				addItem(makeLabel(Translator.map('No motion blocks')));
				return;
			}
		}
		addBlocksForCategory(selectedCategory, catColor);

		updateCheckboxes();
	}

	private function addBlocksForCategory(category:int, catColor:int):void {
		var cmdCount:int;
		var targetObj:ScratchObj = app.viewedObj();
		paletteBlocks = new Array();
		for each (var spec:Array in Specs.commands) {
			if ((spec.length > 3) && (spec[2] == category)) {
				var blockColor:int = (app.interp.isImplemented(spec[3])) ? catColor : 0x505050;
				
				if(!blockLabelCategoryIncluded(spec[0], category))
					blockColor = app.interp.sageDesignMode ? CSS.sageDesignRestricted : 
						(app.interp.sagePlayMode ? CSS.sagePlayRestricted : blockColor);   
						
				var defaultArgs:Array = targetObj.defaultArgsFor(spec[3], spec.slice(4));
				var label:String = spec[0];
				if(targetObj.isStage && spec[3] == 'whenClicked') label = 'when Stage clicked';



				//yc2937 make points editable if we're in design mode
				var block:Block;
				if (app.interp.sageDesignMode == true) {
					block = new Block(label, spec[1], blockColor, spec[3], defaultArgs, true);
				}
				else {
					block = new Block(label, spec[1], blockColor, spec[3], defaultArgs);
				}
				paletteBlocks.push(block); // add to array of all blocks

				var showReporterCheckbox:Boolean = isCheckboxReporter(spec[3]);

				//sm4241- to restrict showing checkbox in play mode
				if (showReporterCheckbox){
					addReporterCheckbox(block);
				} else if(app.interp.sageDesignMode && !app.interp.freeMode){
					if (app.interp.preciseMode) {
						addParsonsCheckInputBox(block);
					} else {
						addParsonsCheckbox(block);
					}
				}

				addItem(block, true);
				cmdCount++;
			} else {
				if ((spec.length == 1) && (cmdCount > 0)) nextY += 10 * spec[0].length; // add some space
				cmdCount = 0;
			}
		}
	}
	
	private function initSageIncludedBlocks():void {
		sageIncludedBlocks = new Dictionary();
		for each (var spec:Array in Specs.commands) {
			if (spec.length > 3)
				sageIncludedBlocks[spec[0]] = true;
		}
	}
	

	protected function addItem(o:DisplayObject, hasCheckbox:Boolean = false):void {
		o.x = hasCheckbox ? 23 : 6;
		o.y = nextY;
		app.palette.addChild(o);
		app.palette.updateSize();
		nextY += o.height + 5;
	}

	private function makeLabel(label:String):TextField {
		var t:TextField = new TextField();
		t.autoSize = TextFieldAutoSize.LEFT;
		t.selectable = false;
		t.background = false;
		t.text = label;
		t.setTextFormat(CSS.normalTextFormat);
		return t;
	}

	private function showMyBlocksPalette(shiftKey:Boolean):void {
		// show creation button, hat, and call blocks
		var catColor:int = Specs.blockColor(Specs.procedureColor);
		addItem(new Button(Translator.map('Make a Block'), makeNewBlock, false, '/help/studio/tips/blocks/make-a-block/'));
		var definitions:Array = app.viewedObj().procedureDefinitions();
		if (definitions.length > 0) {
			nextY += 5;
			for each (var proc:Block in definitions) {
				var b:Block = new Block(proc.spec, ' ', Specs.procedureColor, Specs.CALL, proc.defaultArgValues);
				addItem(b);
			}
			nextY += 5;
		}

		addExtensionButtons();
		for each (var ext:* in app.extensionManager.enabledExtensions()) {
			addExtensionSeparator(ext);
			addBlocksForExtension(ext);
		}

		updateCheckboxes();
	}
//sm4241 - render custom parson palette
	private function showParsonsPalette():void {
		// show creation button, hat, and call blocks

		// these buttons are showing on the front-end instead
//		if(app.interp.sagePlayMode) { // we call the parsons logic
//			addItem(new Button(Translator.map('Question'), showQuestion, false, ''));
//			addItem(new Button(Translator.map('Hint'), showHint, false, ''));
//		}

		if(app.interp.sageDesignMode) { // we call the save project function
			addItem(new Button(Translator.map('Question/Hint/Time'), makeQuestion, false, ''));
		}

		var catColor:int = Specs.blockColor(Specs.parsonsColor);

		if (parsonsBlock.length > 0) {
			nextY += 5;
			for (var i:int=0; i<parsonsBlock.length; i++) {
				var pb:Block = Block (parsonsBlock.getItemAt(i));
				if(sageIncludedBlocks[pb.spec] || pb.op=="readVariable"){
					addItem(Block (parsonsBlock.getItemAt(i)));
				}

			}
			//sm4241

		//	addItem(new Button(Translator.map('Submit'), makeNewBlock, false, '/help/studio/tips/blocks/make-a-block/'));
			if(app.interp.sageDesignMode ) { // we call the save project function
				addItem(new Button(Translator.map('Set Proficiency Scores'), app.getCutoffScores, false, ''));
				
				var count:int = 0;
				if(app.viewedObj().scripts.length >= 1){
					var currBlock:Block = app.viewedObj().scripts[0] as Block;
					while(currBlock != null){
						currBlock = currBlock.nextBlock;
						count++;
					}
				}

				if (count >= 2){
					addItem(new Button(Translator.map('Add feedback for wrong block'), app.getInstructorFeedback, false, ''));
				}
//				addItem(new Button(Translator.map('Save Project'), app.submitProject, false, ''));
			}
			else // we call submission for Parsons function
			{
				// remove submit button in the scratch. Now the submit button is on the front-end
//				addItem(new Button(Translator.map('Submit'), app.getSelfExplanation, false, ''));
			}
			nextY += 5;

		}

		addExtensionButtons();
		for each (var ext:* in app.extensionManager.enabledExtensions()) {
			addExtensionSeparator(ext);
			addBlocksForExtension(ext);
		}

		updateCheckboxes();

		if(app.getFeedback && app.interp.sagePlayMode){
			addItem(new Button(Translator.map('explain step'), app.sendStudentFeedback, false, ''));
		}
	}

	protected function addExtensionButtons():void {
	}

	protected function addAddExtensionButton():void {
		addItem(new Button(Translator.map('Add an Extension'), showAnExtension, false, '/help/studio/tips/blocks/add-an-extension/'));
	}
	
	private function contextMenuTest():void {
		DialogBox.notify('test', 'context');
	}

	private function showDataCategory():void {
		var catColor:int = Specs.variableColor;

// TODO SAGE button block restrictions 
//		var btn:Button = new Button(Translator.map('Make a Variable'), makeVariable)
//		btn.addContextMenu('exclude', contextMenuTest); 
//		addItem(btn);

		// variable buttons, reporters, and set/change blocks
		addItem(new Button(Translator.map('Make a Variable'), makeVariable));
		var varNames:Array = app.runtime.allVarNames().sort();
		if (varNames.length > 0) {
			for each (var n:String in varNames) {
				addVariableCheckbox(n, false);
				addItem(new Block(n, 'r', catColor, Specs.GET_VAR), true);
			}
			nextY += 10;
			addBlocksForCategory(Specs.dataCategory, catColor);
			nextY += 15;
		}

		// lists
		catColor = Specs.listColor;
		addItem(new Button(Translator.map('Make a List'), makeList));

		var listNames:Array = app.runtime.allListNames().sort();
		if (listNames.length > 0) {
			for each (n in listNames) {
				addVariableCheckbox(n, true);
				addItem(new Block(n, 'r', catColor, Specs.GET_LIST), true);
			}
			nextY += 10;
			addBlocksForCategory(Specs.listCategory, catColor);
		}
		updateCheckboxes();
	}

	protected function createVar(name:String, varSettings:VariableSettings):* {
		var obj:ScratchObj = (varSettings.isLocal) ? app.viewedObj() : app.stageObj();
		var variable:* = (varSettings.isList ? obj.lookupOrCreateList(name) : obj.lookupOrCreateVar(name));

		app.runtime.showVarOrListFor(name, varSettings.isList, obj);
		app.setSaveNeeded();

		return variable;
	}

	private function makeVariable():void {
		function makeVar2():void {
			var n:String = d.getField('Variable name').replace(/^\s+|\s+$/g, '');
			if (n.length == 0) return;

			createVar(n, varSettings);
		}

		var d:DialogBox = new DialogBox(makeVar2);
		var varSettings:VariableSettings = makeVarSettings(false, app.viewedObj().isStage);
		d.addTitle('New Variable');
		d.addField('Variable name', 150);
		d.addWidget(varSettings);
		d.addAcceptCancelButtons('OK');
		d.showOnStage(app.stage);
	}

	//sm4241
    private function makeQuestion():void {
        function ok():void {
            inputTime = d.getField("Enter Time (The format should be MM:SS)");
            var arr:Array = inputTime.replace(/^\s+|\s+$/g, '').split(":");
            var message:DialogBox = new DialogBox(null);
            if (arr.length != 2
                    || (isNaN(Number(arr[0])) || Number(arr[0]) < 0 || Number(arr[0]) > 99)
                    || (isNaN(Number(arr[1])) || Number(arr[1]) < 0 || Number(arr[1]) > 59)) {
                message.addTitle("Setting question failed!");
                message.addText("Invalid time input!");
                message.addText(inputTime);
                message.addButton("Close", null);
                message.showOnStage(app.stage);
				question="";
				hint="";
				inputTime=DEFAULT_TIME;
            }
            else {
                question = d.getField("Enter Question");
                hint = d.getField("Enter Hint");
                message.addTitle("Setting question succeeded!");
                var minuteString:String = arr[0] > 1 ? " minutes " : " minute ";
                var secondString:String = arr[1] > 1 ? " seconds " : " second ";
                message.addText("Your question is: " + question + ".\n Your hint is: " + hint +
                        ".\n Time set for this question is: " + arr[0] + minuteString + arr[1] + secondString);
                message.addButton("Close", null);
				trace("Timer set correctly. The remaining time is " + getInputTimeInSeconds())
                message.showOnStage(app.stage);
            }
        }

        var d:DialogBox = new DialogBox(null);
        d.addTitle('Question/Hint');
        d.addField('Enter Question', 350, question);
        d.addField('Enter Hint', 350, hint);
        d.addField('Enter Time (The format should be MM:SS)', 350, inputTime);
        d.addButton('Ok', ok);
        d.addButton('Cancel',null);
        d.showOnStage(app.stage);
    }

	//sm4241
//	private function getComments():void {
//		function ok():void {
//			comments = d.getField("Enter Explanation");
//		}
//
//		var d:DialogBox = new DialogBox(null);
//		d.addTitle('Self-Explanation');
////		d.addTextArea('Enter Explanation', 300, 200, comments);
//		d.addField('Enter Explanation', 500, comments);
//		d.addButton('Ok', ok);
//		d.addButton('Cancel',null);
//		d.showOnStage(app.stage);
//	}

	//sm4241
	private function showQuestion():void {
		function ok():void {
		}
		var d:DialogBox = new DialogBox(null);
		d.addTitle('Question');
		d.addText(question);
		d.addButton('Ok', ok);
		d.showOnStage(app.stage);
	}

	//sm4241
	private function showHint():void {
		function ok():void {
			hintCounter++;
            Scratch.app.decrementPoints(1);
            Scratch.app.getStage().updatePointsLabel();
			Scratch.app.sendUpdatedPointsToServer();
			trace(hintCounter);
		}
		var d:DialogBox = new DialogBox(null);
		d.addTitle('Hint');
		d.addText(hint);
		d.addButton('Ok', ok);
		d.showOnStage(app.stage);
	}

	//jw3564
	public function incrementHintCounter(numberToAdd:int = 1):void {
		hintCounter++;
		trace(hintCounter);
	}

	public function incrementPeerFeedbackCounter(numberToAdd:int = 1):void {
		peerFeedbackCounter++;
		trace(peerFeedbackCounter);
	}


	private function makeList():void {
		function makeList2(d:DialogBox):void {
			var n:String = d.getField('List name').replace(/^\s+|\s+$/g, '');
			if (n.length == 0) return;

			createVar(n, varSettings);
		}
		var d:DialogBox = new DialogBox(makeList2);
		var varSettings:VariableSettings = makeVarSettings(true, app.viewedObj().isStage);
		d.addTitle('New List');
		d.addField('List name', 150);
		d.addWidget(varSettings);
		d.addAcceptCancelButtons('OK');
		d.showOnStage(app.stage);
	}

	protected function makeVarSettings(isList:Boolean, isStage:Boolean):VariableSettings {
		return new VariableSettings(isList, isStage);
	}

	private function makeNewBlock():void {
		function addBlockHat(dialog:DialogBox):void {
			var spec:String = specEditor.spec().replace(/^\s+|\s+$/g, '');
			if (spec.length == 0) return;
			var newHat:Block = new Block(spec, 'p', Specs.procedureColor, Specs.PROCEDURE_DEF);
			newHat.parameterNames = specEditor.inputNames();
			newHat.defaultArgValues = specEditor.defaultArgValues();
			newHat.warpProcFlag = specEditor.warpFlag();
			newHat.setSpec(spec);
			newHat.x = 10 - app.scriptsPane.x + Math.random() * 100;
			newHat.y = 10 - app.scriptsPane.y + Math.random() * 100;
			app.scriptsPane.addChild(newHat);
			app.scriptsPane.saveScripts();
			app.runtime.updateCalls();
			app.updatePalette();
			app.setSaveNeeded();
		}
		var specEditor:ProcedureSpecEditor = new ProcedureSpecEditor('', [], false);
		var d:DialogBox = new DialogBox(addBlockHat);
		d.addTitle('New Block');
		d.addWidget(specEditor);
		d.addAcceptCancelButtons('OK');
		d.showOnStage(app.stage, true);
		specEditor.setInitialFocus();
	}

	private function showAnExtension():void {
		function addExt(ext:ScratchExtension):void {
			if (ext.isInternal) {
				app.extensionManager.setEnabled(ext.name, true);
			} else {
				app.extensionManager.loadCustom(ext);
			}
			app.updatePalette();
		}
		var lib:MediaLibrary = app.getMediaLibrary('extension', addExt);
		lib.open();
	}

	protected function addReporterCheckbox(block:Block):void {
		var b:IconButton = new IconButton(toggleWatcher, 'checkbox');
		b.disableMouseover();
		var targetObj:ScratchObj = isSpriteSpecific(block.op) ? app.viewedObj() : app.stagePane;
		b.clientData = {
			type: 'reporter',
			targetObj: targetObj,
			cmd: block.op,
			block: block,
			color: block.base.color
		};
		b.x = 6;
		b.y = nextY + 5;
		app.palette.addChild(b);
	}

	//sm4241 - checkbox for parsons, before the block
	protected function addParsonsCheckbox(block:Block):void {
		var b:IconButton = new IconButton(parsonsToggleWatcher, 'checkbox');
		b.disableMouseover();
		var targetObj:ScratchObj = isSpriteSpecific(block.op) ? app.viewedObj() : app.stagePane;
		b.clientData = {
			type: 'parsons',
			targetObj: targetObj,
			cmd: block.op,
			block: block,
			color: block.base.color
		};
		b.x = 6;
		b.y = nextY + 5;
		app.palette.addChild(b);
	}

	// pz2244
	protected function addParsonsCheckInputBox(block:Block):void {
		var p:TextPane = new TextPane(typeFunction);
		var targetObj:ScratchObj = isSpriteSpecific(block.op) ? app.viewedObj() : app.stagePane;
		p.scrollbar.visible = false;
		p.textField.restrict = "0-9";

		// TODO show previous data?
		var cnt:Number = 0;
		for (var i = 0; i < parsonsBlock.length; i ++) {
			var bl:Block = Block (parsonsBlock.getItemAt(i));
			if(block.op == bl.op) {
				cnt ++;
			}
		}
		p.setText(cnt.toString());

		p.setWidthHeight(25,18);
		p.clientData = {
			type: 'parsons',
			targetObj: targetObj,
			num: cnt,
			cmd: block.op,
			block: block,
			color: block.base.color
		};

		p.x = 4;
		p.y = nextY + 5;
		app.palette.addChild(p);
	}

	// TODO: keep the number of the parson's block in non-parson's palette
	protected function typeFunction(p:TextPane):void {
		var data:Object = p.clientData;
		if (data.block) {
			switch (data.block.op) {
				case 'senseVideoMotion':
					data.targetObj = getBlockArg(data.block, 1) == 'Stage' ? app.stagePane : app.viewedObj();
				case 'sensor:':
				case 'sensorPressed:':
				case 'timeAndDate':
					data.param = getBlockArg(data.block, 0);
					break;
			}
		}

		var showFlag:Boolean = !app.runtime.watcherShowing(data);
		trace(data.num);
		app.runtime.showWatcher(data, showFlag);
		app.setSaveNeeded();

		// remove previous blocks
		for (var i = parsonsBlock.length - 1; i >= 0; i --) {
			var bl:Block = Block (parsonsBlock.getItemAt(i));
			if(data.block.op == bl.op){
				var index:int = parsonsBlock.getItemIndex(parsonsBlock.getItemAt(i));
				parsonsBlock.removeItemAt(index);
			}
		}

		for (var i = 0; i < data.num; i ++) {
			var newBlock:Block;
			if(data.block){
				newBlock = new Block(data.block.spec, data.block.type, data.color, data.cmd);
			}else{
				newBlock = new Block(data.varName, 'r', Specs.variableColor, Specs.GET_VAR);
				sageIncludedBlocks[data.varName] = true;
			}

			parsonsBlock.addItem(newBlock);
		}

//		if((data.type == "variable" && b.isOn()) || b.isOn() && sageIncludedBlocks[data.block.spec]){
//			parsonsBlock.addItem(newBlock);
//		}else{
//			for (var i:int=0; i<parsonsBlock.length; i++) {
//				var bl:Block = Block (parsonsBlock.getItemAt(i));
//				if(data.block.op == bl.op){
//					var index:int = parsonsBlock.getItemIndex(parsonsBlock.getItemAt(i));
//					parsonsBlock.removeItemAt(index);
//				}
//			}
//			app.getStage().refresh();
//		}

		if(data.type=="parsons"){
			var showFlag:Boolean = !app.runtime.watcherShowing(data);
			app.runtime.showWatcher(data, showFlag);
			app.setSaveNeeded();
		}
	}

	protected function isCheckboxReporter(op:String):Boolean {
		const checkboxReporters: Array = [
			'xpos', 'ypos', 'heading', 'costumeIndex', 'scale', 'volume', 'timeAndDate',
			'backgroundIndex', 'sceneName', 'tempo', 'answer', 'timer', 'soundLevel', 'isLoud',
			'sensor:', 'sensorPressed:', 'senseVideoMotion', 'xScroll', 'yScroll',
			'getDistance', 'getTilt'];
		return checkboxReporters.indexOf(op) > -1;
	}

	private function isSpriteSpecific(op:String):Boolean {
		const spriteSpecific: Array = ['costumeIndex', 'xpos', 'ypos', 'heading', 'scale', 'volume'];
		return spriteSpecific.indexOf(op) > -1;
	}

	private function getBlockArg(b:Block, i:int):String {
		var arg:BlockArg = b.args[i] as BlockArg;
		if (arg) return arg.argValue;
		return '';
	}

	private function addVariableCheckbox(varName:String, isList:Boolean):void {
		var b:IconButton = new IconButton(toggleWatcher, 'checkbox');
		b.disableMouseover();
		var targetObj:ScratchObj = app.viewedObj();
		if (isList) {
			if (targetObj.listNames().indexOf(varName) < 0) targetObj = app.stagePane;
		} else {
			if (targetObj.varNames().indexOf(varName) < 0) targetObj = app.stagePane;
		}
		b.clientData = {
			type: 'variable',
			isList: isList,
			targetObj: targetObj,
			varName: varName
		};
		b.x = 6;
		b.y = nextY + 5;
		app.palette.addChild(b);
	}

	private function toggleWatcher(b:IconButton):void {
		var data:Object = b.clientData;
		if (data.block) {
			switch (data.block.op) {
			case 'senseVideoMotion':
				data.targetObj = getBlockArg(data.block, 1) == 'Stage' ? app.stagePane : app.viewedObj();
			case 'sensor:':
			case 'sensorPressed:':
			case 'timeAndDate':
				data.param = getBlockArg(data.block, 0);
				break;
			}
		}
		//sm4241- cutting off blocks from appearing on stage (to enable showing them up in parsons palette)
		var showFlag:Boolean = !app.runtime.watcherShowing(data);
		app.runtime.showWatcher(data, showFlag);
		b.setOn(showFlag);
		app.setSaveNeeded();
		parsonsToggleWatcher(b);
	}

	//sm4241- cutting off blocks from appearing on stage (to enable showing them up in parsons palette)

	private function parsonsToggleWatcher(b:IconButton):void {
		var data:Object = b.clientData;
		var newBlock:Block;
		if(data.block){
			newBlock = new Block(data.block.spec, data.block.type, data.color, data.cmd);
		}else{
			newBlock = new Block(data.varName, 'r', Specs.variableColor, Specs.GET_VAR);
			sageIncludedBlocks[data.varName] = true;
		}

		if((data.type == "variable" && b.isOn()) || b.isOn() && sageIncludedBlocks[data.block.spec]){
			parsonsBlock.addItem(newBlock);
		}else{
			for (var i:int=0; i<parsonsBlock.length; i++) {
				var bl:Block = Block (parsonsBlock.getItemAt(i));
				if(data.block.op == bl.op){
					var index:int = parsonsBlock.getItemIndex(parsonsBlock.getItemAt(i));
					parsonsBlock.removeItemAt(index);
				}
			}
			app.getStage().refresh();
		}

		if(data.type=="parsons"){
			var showFlag:Boolean = !app.runtime.watcherShowing(data);
			app.runtime.showWatcher(data, showFlag);
			b.setOn(showFlag);
			app.setSaveNeeded();
		}
		//sm4241- cutting off blocks from appearing on stage (to enable showing them up in parsons palette)

	}

	private function updateCheckboxes():void {
		for (var i:int = 0; i < app.palette.numChildren; i++) {
			var b:IconButton = app.palette.getChildAt(i) as IconButton;
			if (b && b.clientData) {
				b.setOn(app.runtime.watcherShowing(b.clientData) || parsonsBlocksContains(b.clientData.cmd));
			}
		}
	}

	private function parsonsBlocksContains(op:String):Boolean {
        for (var i:int = 0; i < parsonsBlock.length; i++) {
            var bl:Block = Block (parsonsBlock.getItemAt(i));
            if(op == bl.op){
                return true;
            }
        }
		return false;
	}

	protected function getExtensionMenu(ext:ScratchExtension):Menu {
		function showAbout():void {
			// Open in the tips window if the URL starts with /info/ and another tab otherwise
			if (ext.url) {
				if (ext.url.indexOf('/info/') === 0) app.showTip(ext.url);
				else if(ext.url.indexOf('http') === 0) navigateToURL(new URLRequest(ext.url));
				else DialogBox.notify('Extensions', 'Unable to load about page: the URL given for extension "' + ext.name + '" is not formatted correctly.');
			}
		}
		function hideExtension():void {
			app.extensionManager.setEnabled(ext.name, false);
			app.updatePalette();
		}

		var m:Menu = new Menu();
		m.addItem(Translator.map('About') + ' ' + ext.name + ' ' + Translator.map('extension') + '...', showAbout, !!ext.url);
		m.addItem('Remove extension blocks', hideExtension);
		return m;
	}

	protected const pwidth:int = 215;
	protected function addExtensionSeparator(ext:ScratchExtension):void {
		function extensionMenu(ignore:*):void {
			var m:Menu = getExtensionMenu(ext);
			m.showOnStage(app.stage);
		}
		nextY += 7;

		var titleButton:IconButton = UIPart.makeMenuButton(ext.name, extensionMenu, true, CSS.textColor);
		titleButton.x = 5;
		titleButton.y = nextY;
		app.palette.addChild(titleButton);

		addLineForExtensionTitle(titleButton, ext);

		var indicator:IndicatorLight = new IndicatorLight(ext);
		indicator.addEventListener(MouseEvent.CLICK, function(e:Event):void {Scratch.app.showTip('extensions');}, false, 0, true);
		app.extensionManager.updateIndicator(indicator, ext);
		indicator.x = pwidth - 30;
		indicator.y = nextY + 2;
		app.palette.addChild(indicator);

		nextY += titleButton.height + 10;
	}

	protected function addLineForExtensionTitle(titleButton:IconButton, ext:ScratchExtension):void {
		var x:int = titleButton.width + 12;
		addLine(x, nextY + 9, pwidth - x - 38);
	}

	private function addBlocksForExtension(ext:ScratchExtension):void {
		var blockColor:int = Specs.extensionsColor;
		var opPrefix:String = ext.useScratchPrimitives ? '' : ext.name + '.';
		for each (var spec:Array in ext.blockSpecs) {
			if (spec.length >= 3) {
				var op:String = opPrefix + spec[2];
				var defaultArgs:Array = spec.slice(3);
				var block:Block = new Block(spec[1], spec[0], blockColor, op, defaultArgs);
				var showCheckbox:Boolean = (spec[0] == 'r' && defaultArgs.length == 0);
				if (showCheckbox) addReporterCheckbox(block);
				addItem(block, showCheckbox);
			} else {
				if (spec.length == 1) nextY += 10 * spec[0].length; // add some space
			}
		}
	}

	protected function addLine(x:int, y:int, w:int):void {
		const light:int = 0xF2F2F2;
		const dark:int = CSS.borderColor - 0x141414;
		var line:Shape = new Shape();
		var g:Graphics = line.graphics;

		g.lineStyle(1, dark, 1, true);
		g.moveTo(0, 0);
		g.lineTo(w, 0);

		g.lineStyle(1, light, 1, true);
		g.moveTo(0, 1);
		g.lineTo(w, 1);
		line.x = x;
		line.y = y;
		app.palette.addChild(line);
	}


	/* Functions for hinting */

	public function getCurrentCategory():int {
		return this.currentCategory;
	}

	public function getBlockByOp(opStr:String):Block {
		for each (var b:Block in this.paletteBlocks) {
			if (opStr == b.op) return b;
		}
		return null; // no block found with given value of 'op'
	}

}}
