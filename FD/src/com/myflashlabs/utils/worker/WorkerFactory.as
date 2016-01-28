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
	import com.codeazur.as3swf.data.SWFSymbol;
	import com.codeazur.as3swf.SWF;
	import com.codeazur.as3swf.tags.ITag;
	import com.codeazur.as3swf.tags.TagDoABC;
	import com.codeazur.as3swf.tags.TagEnableDebugger2;
	import com.codeazur.as3swf.tags.TagEnd;
	import com.codeazur.as3swf.tags.TagFileAttributes;
	import com.codeazur.as3swf.tags.TagShowFrame;
	import com.codeazur.as3swf.tags.TagSymbolClass;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	
	/**
	 * ...
	 * @author Hadi Tavakoli - 1/29/2016 1:17 AM
	 */
	public class WorkerFactory
	{
		
		/**
		 * Creates a Worker from a Class.
		 * @param clazz the Class to create a Worker from
		 * @param bytes SWF ByteArray which must contain the Class definition (usually loaderInfo.bytes)
		 * @param debug set to tru if you want to debug the Worker
		 * @param domain the WorkerDomain to create the Worker in
		 * @return the new Worker
		 */
		public static function getWorkerFromClass(clazz:Class, bytes:ByteArray, debug:Boolean, domain:WorkerDomain, $giveAppPrivileges:Boolean, $parsClasses:Boolean):Worker
		{
			var swf:SWF;
			var tags:Vector.<ITag>;
			var className:String;
			var swfBytes:ByteArray;
			
			if ($parsClasses)
			{
				swf = new SWF(bytes);
				var version:Number = swf.version;
				var compression:Boolean = swf.compressed;
				tags = swf.tags;
				className = getQualifiedClassName(clazz).replace(/::/g, "."); 
				var abcName:String = className.replace(/\./g, "/");
				
				var classTag:ITag;
				var attTag:ITag;
				var metaTag:ITag;
				var bgColorTag:ITag;
				var debugTag:ITag;
				var abcTag:ITag;
				
				for each (var tag:ITag in tags) 
				{
					if (tag is TagSymbolClass)
					{
						for each (var symbol:SWFSymbol in TagSymbolClass(tag).symbols)
						{
							if (symbol.tagId == 0)
							{
								symbol.name = className;
								classTag = tag;
								break;
							}
						}
					}
					else if (tag is TagEnableDebugger2)
					{
						debugTag = tag;
					}
					else if (tag is TagDoABC)
					{
						abcTag = tag;
					}
				}
				
				if (classTag)
				{
					swf = new SWF();
					swf.version = version;
					swf.compressed = compression;
					
					swf.tags.push(new TagFileAttributes());
					if (debug) swf.tags.push(debugTag);
					swf.tags.push(abcTag);
					swf.tags.push(classTag);
					swf.tags.push(new TagShowFrame());
					swf.tags.push(new TagEnd());
					
					swfBytes = new ByteArray();
					swf.publish(swfBytes);
					swfBytes.position = 0;
					
					if (!domain) domain = WorkerDomain.current;
					
					return domain.createWorker(swfBytes, $giveAppPrivileges);
				}
			}
			else
			{
				var i:int;
				swf = new SWF(bytes);
				tags = swf.tags;
				className = getQualifiedClassName(clazz).replace(/::/g, "."); 
				
				for (i = 0; i < tags.length; i++)
				{
					if (tags[i] is TagSymbolClass)
					{
						for each (var sWFSymbol:SWFSymbol in (tags[i] as TagSymbolClass).symbols)
						{
							if (sWFSymbol.tagId == 0)
							{
								sWFSymbol.name = className;
								
								swfBytes = new ByteArray();
								swf.publish(swfBytes);
								swfBytes.position = 0;
								
								if (domain == null)
								{
									domain = WorkerDomain.current;
								}
								
								return domain.createWorker(swfBytes, $giveAppPrivileges);	
							}
						}
					}
				}
			}
			
			return null;
		}
	}
}