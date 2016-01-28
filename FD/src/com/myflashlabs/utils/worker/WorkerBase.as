// =================================================================================================
//	
//	The MIT License (MIT)
//
//	Copyright (c) 2013-2016 MyFlashLabs.com
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//	
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//
//	used and modified:
//	https://github.com/bortsen/worker-from-class
//	https://github.com/claus/as3swf
//	
// =================================================================================================

package com.myflashlabs.utils.worker
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.utils.describeType;
	import flash.utils.getQualifiedClassName;
	
	/**
	 * ...
	 * @author Hadi Tavakoli - 1/29/2016 1:17 AM
	 */
	public class WorkerBase extends Sprite
	{
		private var _incomingChannel:MessageChannel;
		private var _outgoingChannel:MessageChannel;
		
		public function WorkerBase()
		{
			_incomingChannel = Worker.current.getSharedProperty(getQualifiedClassName(this)+"incoming") as MessageChannel;
			_outgoingChannel = Worker.current.getSharedProperty(getQualifiedClassName(this)+"outgoing") as MessageChannel;
			
			_incomingChannel.addEventListener(Event.CHANNEL_MESSAGE, onMessage);
		}
		
		private function onMessage(e:Event):void
		{
			var arr:Array = _incomingChannel.receive();
			var func:Function = this[arr.shift()];
			func.apply(null, arr);
		}
		
		protected function sendProgress($method:Function, ...$params):void
		{
			$params.unshift(getFunctionName($method));
			$params.unshift("type:progress");
			_outgoingChannel.send($params);
		}
		
		protected function sendResult($method:Function, ...$params):void
		{
			$params.unshift(getFunctionName($method));
			_outgoingChannel.send($params);
		}
		
		protected function getFunctionName(callee:Function):String 
		{
			var parent:Object = this;
			for each (var m:XML in describeType(parent)..method)
			{
				if (parent[m.@name] == callee) return m.@name;
			}
			return "not found";
		}
	}
}