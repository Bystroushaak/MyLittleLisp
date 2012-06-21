/**
 * mll.d - My Little Lisp
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.0.2
 * Date:    22.06.2012
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
 * 
 * TODO:
 * 	Preprocesor pro '
*/
import core.exception;

import std.stdio;		// TODO: Odstranit
import std.string;



/* Objects ************************************************************************************************************/
/// Generic object used for representation everything in my little lisp.
class LispObject{
	///
	public string toString(){
		throw new Exception("Unimplemented : toString() for LispObject");
		
		return "";
	}
}


/// Object used for representation of mll arrays.
class LispArray : LispObject{
	public LispObject[] members;
	
	this(LispObject[] members){
		this.members = members;
	}
	
	///
	public string toString(){
		string output;
		
		foreach(LispObject member; this.members){
			output ~= member.toString() ~ " ";
		}
		
		return "(" ~ output[0 .. $-1] ~ ")";
	}
}


/// Object used for representing functions in parsed tree
class LispOperator : LispObject{
	private string name;
	
	public LispObject[] parameters;
	
	this(string name){
		this.name = name;
	}
	
	
	///
	public string toString(){
		return this.name;
	}
}



/* Functions **********************************************************************************************************/
/**
 * FindMatchingBracket - function, which go thru source and returns first matching bracket.
 * 
 * Params:
 * 	source = Lisp source, which MUST begins with bracket, which will used as opening bracket for search.
*/ 
private int findMatchingBracket(string source){
	if (source.length == 0)
		return -1;
	else if (source.length == 1)
		throw new RangeError("Can't find matching bracket - your input string is too small.");
	if (source[0] != '(')
		throw new RangeError("Can't find matching bracket, because your string doesn't start with one!");
	
	// find it
	int i = 1;
	int level = 1;
	for (; i < source.length && level > 0; i++){
		char c = source[i];
		
		if (c == '(')
			level++;
		else if (c == ')')
			level--;
	}
	
	if (level != 0)
		return -1;
	
	return i;
}


LispObject[] cut(string source){
	LispObject[] output;
	
	return output;
}



unittest{
	assert(findMatchingBracket("(cons 1 (cons (q (2 3)) 4)") == -1);
	assert(findMatchingBracket("(cons 1 (cons (q (2 3)) 4))") == "(cons 1 (cons (q (2 3)) 4))".length);
}
































