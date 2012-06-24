/**
 * mll.d - My Little Lisp
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.2.1
 * Date:    24.06.2012
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
 *  Remove var pro EnvStack
*/
module mll;

import core.exception;
import std.algorithm : remove;

import std.stdio;		// TODO: Odstranit
import std.string;


/* Exceptions *********************************************************************************************************/
class LispException : Exception{
	this(string msg){
		super(msg);
	}
}


///
class ParseException : LispException{
	this(string msg){
		super(msg);
	}
}


class UndefinedSymbolException : LispException{
	this(string msg){
		super(msg);
	}
}



/* Objects ************************************************************************************************************/
/// Generic object used for representation everything in my little lisp.
class LispObject{
	/// TODO testnout
	public string toString(){
		if (typeid(this) == typeid(LispArray))
			return (cast(LispArray) this).toString();
		else if (typeid(this) == typeid(LispSymbol))
			return (cast(LispSymbol) this).toString();
			
		throw new Exception("Unimplemented : toString() for LispObject");
	}
	
	public string toLispString(){
		if (typeid(this) == typeid(LispArray))
			return (cast(LispArray) this).toLispString();
		else if (typeid(this) == typeid(LispSymbol))
			return (cast(LispSymbol) this).toLispString();
		
		throw new Exception("Unimplemented : toLispString() for LispObject");
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
		// remove space from the end of last object
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


/// Object used for representing symbols in parsed tree
class LispSymbol : LispObject{
	private string name;
	
	this(string name){
		this.name = name;
	}
	
	public string getName(){
		return this.name;
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



class EnvStack{
	private LispObject[string]   global_env;
	private LispObject[string][] local_env;
	
public:
	///
	this(){
		this.pushLevel();
	}
	
	/**
	 * Create new blank level of variable stack - used for multiple levels of local variables.
	*/ 
	void pushLevel(){
		LispObject[string] le;
		this.local_env ~= le;
	}
	/// See: pushLevel()
	void pushLevel(LispObject[string] new_env){
		this.local_env ~= new_env;
	}
	
	/** 
	 * Remove level of local variables.
	 *
	 * See: pushLevel()
	*/
	void popLevel(){
		if (local_env.length > 1)
			local_env = local_env.remove(local_env.length);
	}
	
	/**
	 * Add new local variable.
	 * 
	 * Variables could be type of LispSymbol or LispList.
	*/ 
	void addLocal(string key, LispObject value){
		this.local_env[local_env.length - 1][key] = value;
	}
	
	/// Same as addLocal, but adds variables to global namespace
	void addGlobal(string key, LispObject value){
		this.global_env[key] = value;
	}
	
	/**
	 * Find and return representation of variable.
	*/ 
	LispObject find(string key){
		for (int i = local_env.length - 1; i >= 0; i--){
			if ((key in local_env[i]) != null) // key in local environment?
				return local_env[i][key];
		}
		
		if ((key in global_env) != null)       // key in global environment?
			return global_env[key];
		
		throw new UndefinedSymbolException("Undefined symbol '" ~ key ~ "'!");
	}
	
	///
	string toString(){
		string output = "Local env:\n";
		
		for (int i = local_env.length - 1; i >= 0; i--){
			output ~= "\t" ~ std.conv.to!string(i) ~ ": " ~ std.conv.to!string(local_env[i]) ~ "\n";
		}
		
		output ~= "\nGlobal env:\n";
		output ~= "\t" ~ std.conv.to!string(global_env) ~ "\n";
		
		return output;
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
 * See: parse() for details
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
		}else{ // parse symbols
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


/**
 * Parse lisp source code to in-memory tree of symbols.
 * 
 * Throws:
 *   ParseException
 *   RangeError
 *
*/ 
public LispArray parse(string source){
	return cast(LispArray) parseTree(source, true)[0];
}



/* Unittests **********************************************************************************************************/
unittest{
	/* findMatchingBracket  *******************************************************************************************/
	assert(findMatchingBracket("(cons 1 (cons (q (2 3)) 4)") == -1);
	assert(findMatchingBracket("(cons 1 (cons (q (2 3)) 4))") == "(cons 1 (cons (q (2 3)) 4))".length);
	
	
	/* splitSymbols ***************************************************************************************************/
	assert(splitSymbols("a b") == ["a", "b"]);
	
	
	/* parse **********************************************************************************************************/
	void testParseWithBothStrings(string expr, string d_result, string lisp_result){
		assert(parse(expr).toString()     == d_result);
		assert(parse(expr).toLispString() == lisp_result);
	}
	testParseWithBothStrings("()", "[[]]", "()");
	testParseWithBothStrings("(a)", "[[a]]", "(a)");
	testParseWithBothStrings("(a (b))", "[[a, [b]]]", "(a (b))");
	testParseWithBothStrings("(a  (     b  )   	)", "[[a, [b]]]", "(a (b))");
	testParseWithBothStrings("((((()))))", "[[[[[[]]]]]]", "()");
	testParseWithBothStrings("(a (b (c (d (e)))))", "[[a, [b, [c, [d, [e]]]]]]", "(a (b (c (d (e)))))");
	
	
	/* EnvStack *******************************************************************************************************/
	EnvStack es = new EnvStack();
	
	// check global environment
	es.addGlobal("plus", parse("(+ 1 2)"));
	assert(es.find("plus").toString() == parse("(+ 1 2)").toString());
	
	// check local environment
	es.addLocal("plus", parse("(++ 1 2)"));
	assert(es.find("plus").toString() == parse("(++ 1 2)").toString());
	
	// check pushLevel()
	es.pushLevel();
	es.addLocal("plus", parse("(+++ 1 2)"));
	assert(es.find("plus").toString() == parse("(+++ 1 2)").toString());
	
	// check popLevel()
	es.popLevel();
	assert(es.find("plus").toString() == parse("(++ 1 2)").toString());
}
































