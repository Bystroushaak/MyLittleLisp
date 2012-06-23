/**
 * mll.d - My Little Lisp
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.1.0
 * Date:    23.06.2012
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
 * 
 * TODO:
 *  Preprocesor pro '
 *  Repl smycku s pocitadlem zavorek, teprve pak evalnout.
 *  skipStringsAndFind(char c) 
 *
*/
module mll;

import core.exception;

import std.stdio;		// TODO: Odstranit
import std.string;


/* Exceptions *********************************************************************************************************/
///
class ParseException : Exception{
	this(string msg){
		super(msg);
	}
}



/* Objects ************************************************************************************************************/
/// Generic object used for representation everything in my little lisp.
class LispObject{
	///
	public string toString(){
		throw new Exception("Unimplemented : toString() for LispObject");
		
		return "";
	}
	
	public string toLispString(){
		throw new Exception("Unimplemented : toLispString() for LispObject");
		
		return "";
	}
}


/// Object used for representation of mll arrays.
class LispArray : LispObject{
	public LispObject[] members;
	
	this(){}
	
	this(LispObject[] members){
		this.members = members;
	}
	
	/// Returns lisp representation of this list
	public string toLispString(){
		string output;
		
		foreach(LispObject member; this.members){
			output ~= member.toLispString() ~ " ";
		}
		
		if (output.length >= 2)
			output.length--;
		
		// do not add () to top level object which contains whole dom
		if (! (members.length == 1 && typeid(this.members[0]) == typeid(LispArray)))
			output = "(" ~ output ~ ")";
		
		return output;
	}

	/// Returns D representation of this list
	public string toString(){
		return std.conv.to!string(members);
	}
}


/// Object used for representing functions in parsed tree
class LispSymbol : LispObject{
	private string name;
	
	this(string name){
		this.name = name;
	}
	
	///
	public string toString(){
		return this.name;
	}
	
	/// Return lisp representation of this object
	public string toLispString(){
		return this.toString();
	}
}



/* Functions **********************************************************************************************************/
/**
 * FindMatchingBracket - function, which go thru source and returns first matching bracket.
 * 
 * Params:
 * 	source = Lisp source, which MUST begins with bracket, which will used as opening bracket for search.
 *
 * TODO:
 *  Add support for builtin strings
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


//TODO: Add support for builtin strings
private string[] splitSymbols(string symbols){
	return symbols.split(" ");
}


/**
 * parseTree
 * 
 * This function splits
 * 
*/ 
private LispObject[] parseTree(string source, bool first){
	LispObject[] output;
	
	source = source.strip();
	
	if (source.length > 0 && source[0] != '(' && first)
		throw new ParseException("Invalid expression.\nCorrect expressions starts with '(', not with '" ~ source[0] ~ "'!");
	
	// create dom tree
	LispArray la = new LispArray();
	while(source.length > 0){
		if (source[0] == '('){ // recursively parse everything inside expression
			int expr_length = findMatchingBracket(source);
			
			if (expr_length < 0)
				throw new ParseException("Unclosed expression!\n>" ~ source ~ "< !!");
			
			if (expr_length >= 2)
				la.members ~= parseTree(source[1 .. expr_length - 1], false); // recursion, whee..
			
			if (expr_length < source.length)
				source = source[expr_length + 1 .. $];
			else
				source.length = 0;
		}else{
			string tmp;
			
			// to tmp save symbols in list until next expression (>>xe xa<< (exp)) -> tmp = xe xa
			int next_expr = source.indexOf('(');
			if (next_expr > 0){
				tmp = source[0 .. next_expr];
				
				if (next_expr < source.length)
					source = source[next_expr .. $];
				else
					source.length = 0;
			}else{
				tmp = source;
				source.length = 0;
			}
			
			// append symbols to the list
			foreach(string symbol; tmp.splitSymbols()){
				symbol = symbol.strip();
				
				if (symbol.length > 0)
					la.members ~= new LispSymbol(symbol);
			}
		}
		
	}
	
	output ~= la;
	
	return output;
}

public LispArray parse(string source){
	return cast(LispArray) parseTree(source, true)[0];
}


unittest{
	// findMatchingBracket
	assert(findMatchingBracket("(cons 1 (cons (q (2 3)) 4)") == -1);
	assert(findMatchingBracket("(cons 1 (cons (q (2 3)) 4))") == "(cons 1 (cons (q (2 3)) 4))".length);
	
	// splitSymbols
	assert(splitSymbols("a b") == ["a", "b"]);
	
	// parse
	void testParseWithBothStrings(string expr, string d_result, string lisp_result){
		assert(parse(expr).toString()     == d_result);
		assert(parse(expr).toLispString() == lisp_result);
	}
	testParseWithBothStrings("()", "[[]]", "()");
	testParseWithBothStrings("(a)", "[[a]]", "(a)");
	testParseWithBothStrings("(a (b))", "[[a, [b]]]", "(a (b))");
	testParseWithBothStrings("(a  (     b  )   	)", "[[a, [b]]]", "(a (b))");
	testParseWithBothStrings("((((()))))", "[[[[[[]]]]]]", "()");
	testParseWithBothStrings("(a (b (c (d (e)))))", "(a (b (c (d (e)))))", "[[a, [b, [c, [d, [e]]]]]]");
}
































