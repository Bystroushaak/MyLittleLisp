/**
 * mll.d - My Little Lisp
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.4.0
 * Date:    25.06.2012
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
///
class UndefinedSymbolException : LispException{
	this(string msg){
		super(msg);
	}
}
///
class BadNumberOfParametersException : LispException{
	this(string msg){
		super(msg);
	}
}


/* Objects ************************************************************************************************************/
/// Generic object used for representation everything in my little lisp.
class LispObject{
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
	private LispObject[] members;
	
	this(){}
	
	this(LispObject[] members){
		this.members = members;
	}
	
	// I didn't wanted to do this, but dmd forced me :( -> "Error: need 'this' to access member members" when calling
	// la.members[0]
	public LispObject[] getMembers(){
		return members;
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


/**
 * LispSymbol - Object used for representing symbols in parsed tree
*/ 
class LispSymbol : LispObject{
	protected string name;
	public    LispSymbol[] params;
	
	this(){}
	this(string name){
		this.name = name;
	}
	this(LispSymbol[] parameters){
		this.params = parameters;
	}
	this(string name, LispSymbol[] parameters){
		this.name   = name; 
		this.params = parameters;
	}
	
	public string getName(){
		return this.name;
	}
	
	// Necesarry when you want to use objects as keys in associative array
	public override bool opEquals(Object o){
		LispSymbol s = cast(LispSymbol) o;
		return s && s.getName() == this.name && s.params.length == this.params.length;
	}
	public override int opCmp(Object o){
		LispSymbol s = cast(LispSymbol) o;
		
		if (!s)
			return -1;
			
		if (!(s && s.opEquals(this) && this.opEquals(s)))
			return -1;

				return this.params.length - s.params.length;
	}
	public override hash_t toHash(){
		return this.name.length + this.params.length;
	}
	
	/// Return lisp representation of this object
	public string toString(){
		if (this.params.length == 0) 
			return this.name;
		
		string output = this.name ~ "(";
		foreach (LispSymbol s; this.params)
			output ~= std.conv.to!string(s) ~ " ";
		
		// remove space from the end
		if (this.params.length > 0 && output.length > 1)
			output.length--;
		
		return output ~ ")";
	}
	public override string toLispString(){
		string output;
		
		if (this.params.length == 0)
			return this.name;
		
		output ~= "(defun "  ~ this.name ~ " (lambda (";
		
		foreach (LispSymbol s; this.params)
			output ~= std.conv.to!string(s) ~ " ";
		
		// remove space from the end
		if (this.params.length > 0 && output.length > 1)
			output.length--;
		
		output ~= ") (";
		
		// TODO: dodělat - výpis těla z EnvStacku
		
		return output ~ "))";
	}
	
}



class EnvStack{
	private LispObject[LispSymbol]   global_env;
	private LispObject[LispSymbol][] local_env;
	
public:
	///
	this(){
		this.pushLevel();
	}
	
	/**
	 * Create new blank level of variable stack - used for multiple levels of local variables.
	*/ 
	void pushLevel(){
		LispObject[LispSymbol] le;
		this.local_env ~= le;
	}
	/// See: pushLevel()
	void pushLevel(LispObject[LispSymbol] new_env){
		this.local_env ~= new_env;
	}
	
	/** 
	 * Remove level of local variables.
	 *
	 * See: pushLevel()
	*/
	void popLevel(){
		if (local_env.length > 1)
			local_env = local_env.remove(local_env.length - 1);
	}
	
	/**
	 * Add new local variable.
	 * 
	 * Variables could be type of LispSymbol or LispList.
	*/ 
	void addLocal(LispSymbol key, LispObject value){
		this.local_env[local_env.length - 1][key] = value;
	}
	
	/// Same as addLocal, but adds variables to global namespace
	void addGlobal(LispSymbol key, LispObject value){
		this.global_env[key] = value;
	}
	
	/**
	 * Find and return representation of variable.
	*/ 
	LispObject find(LispSymbol key){
		for (int i = local_env.length - 1; i >= 0; i--){
			if (key in local_env[i]) // key in local environment?
				return local_env[i][key];
		}
		
		if (key in global_env)       // key in global environment?
			return global_env[key];
		
		throw new UndefinedSymbolException("Undefined symbol '" ~ std.conv.to!string(key) ~ "'!");
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




/***********************************************************************************************************************
* Functions ************************************************************************************************************
***********************************************************************************************************************/
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



public LispObject eval(LispObject expr, EnvStack env){
	env.pushLevel();     // install new local namespace
	scope(exit){        // D, fuck yeah
		env.popLevel();
	}
	
	writeln("incomming: ", expr.toLispString());
	
	LispArray la;
	LispSymbol s;
	LispObject[] members;
	if (typeid(expr) == typeid(LispSymbol)){ // handle variables
		s = cast(LispSymbol) expr;
		
		// look to the symbol table, return saved value, numeric value, or throw error, if expr is not value/number
		try{
			return env.find(s); // return saved value
		}catch(UndefinedSymbolException e){
			try{
				std.conv.to!int(s.getName());
			}catch(std.conv.ConvException){
				try{
					std.conv.to!double(s.getName());
				}catch(std.conv.ConvException){
					throw new UndefinedSymbolException(e.msg);
				}
			}
		}
		
		return s; // return numeric value
	}else if ((typeid(expr) == typeid(LispArray)) && // builtin keyword calling;     gimme LispArray
	           ((members = (la = cast(LispArray) expr).getMembers()).length > 0) && // which have one or more members
	           (typeid(members[0]) == typeid(LispSymbol))                       ){ // and first member is LispSymbol
		s = cast(LispSymbol) members[0];                                            // get function name
		
		/* Internal keyword definitions *******************************************************************************/
		if (s.getName().toLower() == "lambda") 
			return la; // lambdas are returned back, because eval evals them later with args
		else if (s.getName().toLower() == "q" || s.getName().toLower() == "quote"){
			if (members.length == 1)
				throw new BadNumberOfParametersException("quote expects one or more parameters!");
			
			if (members.length == 2)
				return members[1];
			else
				return new LispArray(members[1 .. $]);
		}
	}
	
	// eval every expression in list
	LispObject[] exps;
	foreach(LispObject o; (cast(LispArray) expr).getMembers())
		exps ~= eval(o, env);
	
	// values are just returned
	if (exps.length == 1)
		return exps[0];
		
	LispObject fn = exps[0];
	exps = exps.remove(0);
	
	
	// executor - thic block executes function calls
	if (typeid(fn) == typeid(LispSymbol)){       // named function evaluation
		
		throw new LispException("Undefined function lookup!");
	}else if (typeid(fn) == typeid(LispArray)){ // lambda evaluation
		la = cast(LispArray) fn;
		members = la.getMembers();
		
		if (members.length > 0 && typeid(members[0]) == typeid(LispSymbol) && (s = cast(LispSymbol) members[0]).getName().toLower() == "lambda"){
			LispObject output;
			
			// install parameters
			if (members.length != 3)
				throw new BadNumberOfParametersException("lambda must have 2 parameters!"); // lambda, params, body
			
			LispObject parameters  = members[1];
			LispObject lambda_body = members[2];
			
			if (typeid(parameters) == typeid(LispSymbol)){
				if (exps.length != 1)
					throw new BadNumberOfParametersException(
						"This lambda expression expects only one parameter, but you try to call it with " ~ 
						std.conv.to!string(exps.length) ~ "!");
				
				env.pushLevel();
				env.addLocal(cast(LispSymbol) parameters, exps[0]);
			}else if (typeid(parameters) == typeid(LispArray)){
				la = cast(LispArray) parameters;
				members = la.getMembers();
				
				writeln(members, "==", exps);
				
				if (members.length != exps.length)
					throw new BadNumberOfParametersException(
						"This lambda expression expects " ~ std.conv.to!string(members.length) ~ 
						" parameters, not " ~ std.conv.to!string(exps.length) ~  "!");
				
				env.pushLevel();
				for(int i = 0; i < members.length; i++){
					s = cast(LispSymbol) members[i];
					
					if (!s){
						env.popLevel();
						throw new LispException("Parameter names must be symbols, not arrays!");
					}
					
					env.addLocal(s, exps[i]);
				}
			}else{
				throw new LispException("Unknown type of parameters for your lambda call - you did some weird shit, didn't you?");
			}
			
			// return evaluated lambda
			output = eval(lambda_body, env);
			env.popLevel(); // remove lambda parameters
			return output;
		}
	}
	
	throw new UndefinedSymbolException("Undefined symbol or builtin keyword '" ~ std.conv.to!string(expr) ~ "'!");
}



/* Unittests **********************************************************************************************************/
unittest{
	/* LispSymbol *****************************************************************************************************/
	LispSymbol s1 = new LispSymbol("asd");
	LispSymbol s2 = new LispSymbol("asd");
	LispSymbol s3 = new LispSymbol("bsd");
	assert(s1 == s2);
	assert(s2 == s1);
	assert(s2 != s3);
	assert(s1 != s3);
	
	int[LispSymbol] aa;
	aa[s1] = 2;
	assert(s1 in aa);
	assert(s2 in aa);
	assert(!(s3 in aa));
	
	LispSymbol s4 = new LispSymbol("asd");
	LispSymbol s5 = new LispSymbol("asd", [new LispSymbol("a"), new LispSymbol("b")]);
	LispSymbol s6 = new LispSymbol("asd", [new LispSymbol("x"), new LispSymbol("y")]);
	
	assert(s4 != s5);
	assert(s4 != s6);
	
	assert(s5 == s6);
	
	
	/* findMatchingBracket ********************************************************************************************/
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
	es.addGlobal(new LispSymbol("plus"), parse("(+ 1 2)"));
	assert(es.find(new LispSymbol("plus")).toString() == parse("(+ 1 2)").toString());
	
	// check local environment
	es.addLocal(new LispSymbol("plus"), parse("(++ 1 2)"));
	assert(es.find(new LispSymbol("plus")).toString() == parse("(++ 1 2)").toString());
	
	// check pushLevel()
	es.pushLevel();
	es.addLocal(new LispSymbol("plus"), parse("(+++ 1 2)"));
	assert(es.find(new LispSymbol("plus")).toString() == parse("(+++ 1 2)").toString());
	
	// check popLevel()
	es.popLevel();
	assert(es.find(new LispSymbol("plus")).toString() == parse("(++ 1 2)").toString());
}
































