/**
 * mll.d - My Little Lisp
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.8.0
 * Date:    03.07.2012
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
 * 
 * TODO:
 *  Repl smycku s pocitadlem zavorek, teprve pak evalnout.
 *  skipStringsAndFind(char c) 
 *  Nekonečná přesnost čísel
 *  
 *  Remove var pro EnvStack
 *  Přetížit opEquals pro lisp symbol a odstranit getName()
*/
module mll;

import std.string;
import core.exception;

import std.conv : to;
import std.algorithm : remove;


import std.stdio;		// TODO: Odstranit


const string INF_PARAMS = "...";
enum string[char] quoters = ['\'':"quote", '`':"quasiquote", ',':"unquote"];


/***********************************************************************************************************************
* Exceptions ***********************************************************************************************************
 ***********************************************************************************************************************
 * Exception tree:
 *
 *   Exception
 *   '-> LispException
 *       |-> UndefinedSymbolException
 *       |-> BadNumberOfParametersException
 *       |-> BadTypeOfParametersException
 *       '-> ParseEception
 *           '-> BlankExpressionException
 *
*/ 
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
class BlankExpressionException : ParseException{
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
///
class BadTypeOfParametersException : LispException{
	this(string msg){
		super(msg);
	}
}



/***********************************************************************************************************************
* Objects **************************************************************************************************************
***********************************************************************************************************************/
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
		return members.dup;
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
		return to!string(members);
	}
	
	public bool opEquals(Object o){
		LispArray a = cast(LispArray) o;
		
		if (a is null)
			return false;
		
		LispObject[] arr_members = a.getMembers();
		if (arr_members.length != this.members.length)
			return false;
		
		for(int i = 0; i < this.members.length; i++){
			if (typeid(this.members[i]) != typeid(arr_members))
				return false;
			
			if (this.members[i] != arr_members[i])
				return false;
		}
		
		return true;
	}
}


/**
 * LispSymbol - Object used for representing symbols in parsed tree
*/ 
class LispSymbol : LispObject{
	private string   name;
	
	this(){}
	this(string name){
		this.name = name;
	}
	
	public string getName(){
		return this.name;
	}
	
	// Necesarry when you want to use objects as keys in associative array
	public override bool opEquals(Object o){
		LispSymbol s = cast(LispSymbol) o;
		return s && s.getName() == this.name;
	}
	public override int opCmp(Object o){
		LispSymbol s = cast(LispSymbol) o;
		
		if (!s)
			return -1;
			
		if (!(s && s.opEquals(this) && this.opEquals(s)))
			return -1;
		
		return this.name.length - s.name.length;
	}
	public override hash_t toHash(){
		return this.name.length;
	}
	
	/// Return lisp representation of this object
	public string toString(){
		return this.name;
	}
	public override string toLispString(){
		return this.name;
	}
}


/**
 * Environment Stack
 * 
 * This object is used for storing functions and variables.
*/ 
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
	 * Add new local (temporary) variable - this is used for mapping function arguments to local namespace.
	*/ 
	void addLocal(LispSymbol key, LispObject value){
			this.local_env[$ - 1][key] = value;
	}
	
	/** 
	 * Add new local variable.
	 * 
	 * This function puts variables one level higher than addLocal()'(a v bh, so they survive definition (which happens in 
	 * its own separate namespace, because every eval() call creates one).
	 * 
	 * Variables could be type of LispSymbol or LispList.
	*/ 
	void addLocalVariable(LispSymbol key, LispObject value){
			if (this.local_env.length >= 1)
				this.local_env[$ - 2][key] = value;
			else
				this.local_env[0][key] = value;
	}
	
	/// Same as addLocal, but adds variables to global namespace
	void addGlobal(LispSymbol key, LispObject value){
		this.global_env[key] = value;
	}
	
	/**
	 * Find and return representation of symbol.
	 * 
	 * Throws:
	 *   UndefinedSymbolException
	*/ 
	LispObject find(LispSymbol key){
		try
			return findLocal(key);
		catch(UndefinedSymbolException e)
			return findGlobal(key);
	}
	/// Find local variable or throw UndefinedSymbolException error.
	LispObject findLocal(LispSymbol key){
		for (int i = local_env.length - 1; i >= 0; i--){
			if (key in local_env[i]) // key in local environment?
				return local_env[i][key];
		}
		
		throw new UndefinedSymbolException("Undefined symbol '" ~ to!string(key) ~ "'!");
	}
	/// Find global variable or throw UndefinedSymbolException error.
	LispObject findGlobal(LispSymbol key){
		if (key in global_env)       // key in global environment?
			return global_env[key];
		
		throw new UndefinedSymbolException("Undefined symbol '" ~ to!string(key) ~ "'!");
	}
	
	/**
	 * Set value of DEFINED symbol.
	 * 
	 * Throws:
	 *   UndefinedSymbolException
	*/ 
	void set(LispSymbol key, LispObject val){
		for (int i = local_env.length - 1; i >= 0; i--){
			if (key in local_env[i]){ // key in local environment?
				local_env[i][key] = val;
				return;
			}
		}
		
		if (key in global_env){       // key in global environment?
			global_env[key] = val;
			return;
		}
		
		throw new UndefinedSymbolException("Undefined symbol '" ~ to!string(key) ~ "'!");
	}
	
	///
	string toString(){
		string output = "Local env:\n";
		
		for (int i = local_env.length - 1; i >= 0; i--){
			output ~= "\t" ~ to!string(i) ~ ": " ~ to!string(local_env[i]) ~ "\n";
		}
		
		output ~= "\nGlobal env:\n";
		output ~= "\t" ~ to!string(global_env) ~ "\n";
		
		return output;
	}
	
	string toLispString(){
		string output = "((local (\n";
		
		for (int i = local_env.length - 1; i >= 0; i--){
			output ~= "\t(q (" ~ to!string(i) ~ "))\n";
		}
		
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
	
	if (source.length > 0 && std.algorithm.indexOf(['\'', '`', ',', '('], source[0]) < 0 && first)
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
 * Convert lisp tree from parse() with syntax sugar `', to clear lisp containing only quasiquote, quote and unquote.
*/ 
LispObject sugarToRealLisp(LispObject o){
	LispArray  a;
	LispSymbol s;
	string name;
	
	if ((s = cast(LispSymbol) o) !is null){ // symbols quotation
		name = s.getName();
		
		if (name.length > 1 && std.algorithm.indexOf(['\'', '`', ','], name[0]) >= 0){ // if symbol starts with quoter
			return new LispArray([new LispSymbol(quoters[name[0]]), new LispSymbol(name.length > 2 ? name[1 .. $] : "" ~ name[1])]);
		}else if (std.algorithm.indexOf(['\'', '`', ','], name[0]) >= 0) // symbol IS quoter
			throw new ParseException("Misplaced quoter >" ~ name ~ "< - quoters can't be used as symbols!");
		else
			return o;
	}else if ((a = cast(LispArray) o) !is null){ // arays quotation
		LispArray output = new LispArray();
		LispObject[] members = a.getMembers();
		
		LispObject m;
		for(int i = 0; i < members.length; i++){
			m = members[i];
			if ((s = cast(LispSymbol) m) !is null){
				name = s.getName();
				
				// quote array
				if (name.length == 1 && std.algorithm.indexOf(['\'', '`', ','], name[0]) >= 0){ // quoter before array
					if (i + 1 <= members.length - 1){
						if ((a = cast(LispArray) members[i + 1]) !is null){
							output.members ~= new LispArray([new LispSymbol(quoters[name[0]]), sugarToRealLisp(a)]);
							i += 2;
						}else // quoter at the and of list
							throw new ParseException("Misplaced quoter >" ~ name ~ "< - quoters can't be used as symbols!");
					}else
						throw new ParseException("Misplaced quoter >" ~ name ~ "< - quoters can't be used as symbols!");
				}else
					output.members ~= sugarToRealLisp(m);
			}else if ((a = cast(LispArray) m) !is null) // arrays are recursively quoted 
				output.members ~= sugarToRealLisp(m);
			else
				throw new ParseException("Can't remove sugar - LispObject is not supported in arrays!");
		}
		
		return output;
	}else 
		throw new ParseException("Can't remove sugar - LispObject is not supported!");
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
	source = source.strip();
	if (source.length == 0)
		return new LispArray();
	
	if (std.algorithm.indexOf(['\'', '`', ','], source[0]) >= 0)
		return cast(LispArray) (cast(LispArray) parseTree("(" ~ source ~ ")", true)[0]).getMembers()[0];
	else
		return cast(LispArray) (cast(LispArray) parseTree(source, true)[0]).getMembers()[0];
}




bool isNumeric(LispObject o){
	LispSymbol s = cast(LispSymbol) o;
	
	if (s is null)
		return false;
	
	try{
		to!int(s.getName());
	}catch(std.conv.ConvException){
		try{
			to!double(s.getName());
		}catch(std.conv.ConvException){
			return false;
		}
	}
	
	return true;
}
bool isDouble(LispSymbol s){
	if (!isNumeric(s))
		return false;
	
	if (s.getName().indexOf(",") >= 0 || s.getName().indexOf(".") >= 0)
		return true;
	
	return false;
}



/**
 * Evaluate expression expr in environment env.
 * 
 * Params:
 *  expr = parsed tree of lisp expressions
 *  env  = environment of variables
*/ 
public LispObject eval(LispObject expr, EnvStack env){
	env.pushLevel();     // install new local namespace
	scope(exit){        // D, fuck yeah
		env.popLevel();
	}
	
	LispArray la;
	LispSymbol s;
	LispObject[] parameters;
	if (typeid(expr) == typeid(LispSymbol)){ // handle variables
		s = cast(LispSymbol) expr;
		
		// look to the symbol table, return saved value, numeric value, or throw error, if expr is not value/number
		try{
			return env.find(s); // return saved value
		}catch(UndefinedSymbolException e){
			try{
				to!long(s.getName());
			}catch(std.conv.ConvException){
				try{
					to!double(s.getName());
				}catch(std.conv.ConvException){
					throw new UndefinedSymbolException(e.msg);
				}
			}
		}
		return s; // return numeric value
	}else if ((typeid(expr) == typeid(LispArray)) && // builtin keyword calling;        gimme LispArray
	           ((parameters = (la = cast(LispArray) expr).getMembers()).length > 0) && // which have one or more members
	           (typeid(parameters[0]) == typeid(LispSymbol))                       ){ // and first member is LispSymbol
		// save useful information
		
		s = cast(LispSymbol) parameters[0];
		string name = s.getName().toLower();
		parameters = parameters.remove(0); // get parameters
		
		void checkParamLength(LispObject[] parameters, int expected_length, string name){
			if (expected_length == 1 && parameters.length != 1)
				throw new BadNumberOfParametersException(name ~ " expects only one parameter!");
			else if (expected_length == 2 && parameters.length != 2)
				throw new BadNumberOfParametersException(name ~ " expects two parameters!");
			else if (expected_length != parameters.length)
				throw new BadNumberOfParametersException(name ~ " expects " ~ to!string(expected_length) ~ 
				                                          " parameters, not " ~ to!string(parameters.length) ~ "!");
		}
		
		/* Internal keyword definitions *******************************************************************************/
		if (name == "lambda"){
			checkParamLength(parameters, 2, "lambda");
			return expr; // lambdas are returned back, because eval evals them later with args
		}else if (name == "macro"){
			checkParamLength(parameters, 2, "macro");
			return expr; // macros are practically same as lambda
		}else if (name == "q" || name == "quote"){
			checkParamLength(parameters, 1, "quote");
			return parameters[0];
		}else if (name == "uq" || name == "unquote"){
			checkParamLength(parameters, 1, "unquote");
			return eval(new LispArray(parameters), env); // xex, eval really evaluate only lists
		}else if (name == "qq" || name == "quasiquote"){
			LispObject[] output;
			
			// eval unquote in quasiquotes
			if (parameters.length == 2 && (s = cast(LispSymbol) parameters[0]) !is null && (s.getName() == "uq" || s.getName() == "unquote"))
				return eval(parameters[1], env);
			
			// ou yeah, recursively make everything quasiquote
			foreach(LispObject p; parameters){
				if (typeid(p) == typeid(LispSymbol))
					output ~= p;
				else{
					la = cast(LispArray) p;
					output ~= eval(new LispArray([cast(LispObject) new LispSymbol("qq")] ~ la.getMembers()), env);
				}
			}
			
			return new LispArray(output);
		}else if (name == "list"){
			return new LispArray(parameters);
		}else if (name == "cons"){
			checkParamLength(parameters, 2, "cons");
			
			LispObject[] output;
			
			foreach(LispObject lo; parameters){
				lo = eval(lo, env);
				
				if (typeid(lo) == typeid(LispSymbol))
					output ~= lo;
				else if (typeid(lo) == typeid(LispArray))
					output ~= (cast(LispArray) lo).getMembers();
			}
			
			return new LispArray(output);
		}else if (name == "defl" || name == "defg"){
			checkParamLength(parameters, 2, "defl/defg");
			
			// first parameter must be symbol - if parameter is array, try evaluate it to get symbol
			if (typeid(parameters[0]) == typeid(LispArray))
				s = cast(LispSymbol) eval(parameters[0], env);
			else
				s = cast(LispSymbol) parameters[0];
			if (!s)
				throw new BadTypeOfParametersException("Can't use " ~ s.toLispString() ~ " as idenfiticator!");
			
			parameters[1] = eval(parameters[1], env);
			
			if (name == "defg")
				env.addGlobal(s, parameters[1]);
			else
				env.addLocalVariable(s, parameters[1]);
			
			return s;
		}else if (name == "set!"){
			checkParamLength(parameters, 2, "set!");
			
			// first parameter must be symbol - if parameter is array, try evaluate it to get symbol
			if (typeid(parameters[0]) == typeid(LispArray))
				s = cast(LispSymbol) eval(parameters[0], env);
			else
				s = cast(LispSymbol) parameters[0];
			if (!s)
				throw new BadTypeOfParametersException("Can't use " ~ s.toLispString() ~ " as idenfiticator!");
			
			env.set(s, parameters[1]);
			
			return s;
		}else if (name == "car"){
			checkParamLength(parameters, 1, "car");
				
			parameters[0] = eval(parameters[0], env);
			
			if (typeid(parameters[0]) != typeid(LispArray))
				throw new BadTypeOfParametersException(parameters[0].toLispString() ~ " is not a list!");
			
			if ((la = cast(LispArray) parameters[0]).getMembers().length > 0)
				return la.getMembers()[0];
			else
				return new LispArray();
		}else if (name == "cdr"){
			checkParamLength(parameters, 1, "cdr");
				
			parameters[0] = eval(parameters[0], env);
			
			if (typeid(parameters[0]) != typeid(LispArray))
				throw new BadTypeOfParametersException(parameters[0].toLispString() ~ " is not a list!");
			
			if ((la = cast(LispArray) parameters[0]).getMembers().length > 1)
				return new LispArray(la.getMembers()[1 .. $]);
			else
				return new LispArray();
		}else if (name == "eq"){
			checkParamLength(parameters, 2, "eq");
			
			if (eval(parameters[0], env) == eval(parameters[1], env))
				return new LispArray([new LispSymbol("t")]);
			else
				return new LispArray();
		}else if (name == "atom?"){
			checkParamLength(parameters, 1, "atom?");
			
			s = cast(LispSymbol) eval(parameters[0], env);
			if (s is null)
				return new LispArray();
			
			try
				to!int(s.getName());
			catch(std.conv.ConvException)
				try
					to!double(s.getName());
				catch(std.conv.ConvException)
					return new LispArray();
			
			return new LispArray([new LispSymbol("t")]); 
		}else if (name == "null?"){
			checkParamLength(parameters, 1, "null?");
			
			la = cast(LispArray) eval(parameters[0], env);
			if (la && la.getMembers().length == 0)
				return new LispArray([new LispSymbol("t")]);
			else 
				return new LispArray();
		}else if (name == "if"){
			checkParamLength(parameters, 3, "if");
			
			la = cast(LispArray) eval(parameters[0], env);
			if (la && la.getMembers().length == 0) // == false
				return eval(parameters[2], env);
			else
				return eval(parameters[1], env);
		}else if (name == "cond"){
			if (parameters.length == 0)
				throw new BadTypeOfParametersException("cond requires at least one parameter!");
			
			foreach(LispObject o; parameters){
//				o = eval(o, env);
				la = cast(LispArray) o;
				if (la is null)
					throw new BadTypeOfParametersException("Can't use symbols as parameters!");
				
				LispObject[] cond_params = la.getMembers();
				if (cond_params.length != 2)
					throw new BadNumberOfParametersException("cond expects pair of arguments!");
				
				la = cast(LispArray) eval(cond_params[0], env);
				if (! (la && la.getMembers().length == 0)) // == true
					return eval(cond_params[1], env);
			}
		}else if (std.algorithm.indexOf(["+", "-", "*", "/"], name) >= 0){ // arithmetic, wheee
			if (parameters.length < 2 && name != "-")
				throw new BadNumberOfParametersException(name ~ " require at least two parameters!");
			else if (parameters.length < 1 && name == "-")
				throw new BadNumberOfParametersException("- requires at least one parameter!");
			
			// check if parameters are numbers
			LispObject o; 
			LispSymbol[] args;
			foreach(LispObject arg; parameters){
				o = eval(arg, env);
				if ((s = cast(LispSymbol) o) is null || !isNumeric(s))
					throw new BadTypeOfParametersException(name ~ "expects only numbers as parameters!");
				args ~= s;
			}
			
			// double vs int values :3
			long   iresult;
			double dresult;
			bool   use_iresult = !isDouble(args[0]);
			if (use_iresult)
				iresult = to!long(args[0].getName());
			else
				dresult = to!double(args[0].getName());
			
			if (args.length == 1 && name == "-")
				return new LispSymbol(to!string(0 - (use_iresult ? iresult : dresult)));
			
			args = args.remove(0);
			foreach(LispSymbol arg; args){
				if (use_iresult && arg.isDouble()){
					dresult = iresult;
					use_iresult = false;
				}
				
				if (name == "+"){
					if (use_iresult)
						iresult += to!long(arg.getName());
					else
						dresult += to!double(arg.getName());
				}else if (name == "-"){
					if (use_iresult)
						iresult -= to!long(arg.getName());
					else
						dresult -= to!double(arg.getName());
				}else if (name == "*"){
					if (use_iresult)
						iresult *= to!long(arg.getName());
					else
						dresult *= to!double(arg.getName());
				}else if (name == "/"){
					if (use_iresult)
						iresult /= to!long(arg.getName());
					else
						dresult /= to!double(arg.getName());
				}else
					throw new LispException("Goofy please..");
			}
			
			return new LispSymbol(to!string(use_iresult ? iresult : dresult));
		}else if (std.algorithm.indexOf(["<", ">", "<=", ">=", "="], name) >= 0){
			checkParamLength(parameters, 2, name);
			
			LispSymbol p1 = cast(LispSymbol) parameters[0];
			LispSymbol p2 = cast(LispSymbol) parameters[1];
			
			if (p1 is null || p2 is null)
				throw new BadTypeOfParametersException(name ~ " parameters can't be lists!");
			if (!(isNumeric(p1) && isNumeric(p2)))
				throw new BadTypeOfParametersException(name ~ " parameters must be numeric!");
			
			double n1, n2;
			n1 = to!double(p1.getName());
			n2 = to!double(p2.getName());
			
			if (name == "<")
				return (n1 < n2 ? new LispArray([new LispSymbol("t")]) : new LispArray());
			else if (name == ">")
				return (n1 > n2 ? new LispArray([new LispSymbol("t")]) : new LispArray());
			else if (name == "<=")
				return (n1 <= n2 ? new LispArray([new LispSymbol("t")]) : new LispArray());
			else if (name == ">=")
				return (n1 >= n2 ? new LispArray([new LispSymbol("t")]) : new LispArray());
			else if (name == "=")
				return (n1 == n2 ? new LispArray([new LispSymbol("t")]) : new LispArray());
			else 
				throw new LispException("Goofy please..");
		}
	}else if ((typeid(expr) == typeid(LispArray)) && // macro call                   // gimme LispArray
	           ((parameters = (la = cast(LispArray) expr).getMembers()).length > 0) && // which have one or more members
	           (typeid(parameters[0]) == typeid(LispArray))){                         // and first member is LispArray
		la = cast(LispArray) parameters[0]; // 
		if (la.getMembers().length == 3 && (s = cast(LispSymbol) la.getMembers()[0]) !is null && s.getName().toLower() == "macro"){
			LispObject[] parnames_body = la.getMembers();
			LispObject[] par_values = parameters.length == 2 ? [cast(LispObject) parameters[1]] : parameters[1 .. $];
			
			return evalFunctionCall(parnames_body[2], 
				                     parnames_body[1], 
				                     par_values, 
				                     env, 
				                     "macro");
		} // nonmacro keywords fall to eval/lambda evaluation block
	}
	
	// eval every expression in list
	LispObject[] par_values;
	foreach(LispObject o; (cast(LispArray) expr).getMembers())
		par_values ~= eval(o, env);
	
	if (par_values.length == 0)
		return expr;
	
	// separate function name from parameters
	LispObject fn = par_values[0];
	par_values = par_values.remove(0);
	
	/* Executor - thic block executes function calls ******************************************************************/
	if (typeid(fn) == typeid(LispArray)){ // lambda evaluation
		la = cast(LispArray) fn;
		parameters = la.getMembers();
		
		if (parameters.length > 0 && typeid(parameters[0]) == typeid(LispSymbol) && (s = cast(LispSymbol) parameters[0]).getName().toLower() == "lambda"){
			if (parameters.length != 3)
				throw new BadNumberOfParametersException("lambda takes two parameters!"); // lambda, params, body
			
			return evalFunctionCall(parameters[2], parameters[1], par_values, env);
		}else
			return eval(fn, env);
	}
	
	throw new UndefinedSymbolException("Undefined symbol or builtin keyword '" ~ fn.toLispString() ~ "'!");
}


/**
 * Map parameters to the new local namespace and evaluate function body after that.
 * 
 * This function maps par_names:par_values to enviroment env and then runs the function_body.
*/ 
private LispObject evalFunctionCall(LispObject function_body, LispObject par_names, LispObject[] par_values, EnvStack env, string type = "lambda"){
	LispArray la;
	LispSymbol s;
	LispObject[] members;
	
	// create local namespace for variables
	env.pushLevel();
	scope(exit){
		env.popLevel();
	}
	
	if ((s = cast(LispSymbol) par_names) !is null){ // one parameter
		if (s.getName() == INF_PARAMS){
			env.addLocal(s, new LispArray(par_values));
		}else{
			if (par_values.length != 1)
				throw new BadNumberOfParametersException(
					"This " ~ type ~ " expression takes exactly one parameter, not " ~ 
					to!string(par_values.length) ~ "!");
		
			env.addLocal(s, par_values[0]);
		}
	}else if (typeid(par_names) == typeid(LispArray)){ // multiple parameters
		la = cast(LispArray) par_names;
		members = la.getMembers();
		
		// there must be equal number of parameters and their values
		if (members.length > par_values.length)
			throw new BadNumberOfParametersException(
				"This " ~ type ~ " expression expects " ~ to!string(members.length) ~ 
				" parameters, not " ~ to!string(par_values.length) ~  "!");
		
		// put parameters into lambda environment
		for(int i = 0; i < members.length; i++){
			if (i >= members.length)
				throw new BadNumberOfParametersException("Not enough parameters for this " ~ type ~ " call!");
			if (i >= par_values.length)
				throw new BadNumberOfParametersException("Too many parameters for this " ~ type ~ " call!");
				
			s = cast(LispSymbol) members[i];
			
			if (!s)
				throw new BadTypeOfParametersException("Parameter names must be symbols, not lists!");
			
			if (s.getName() == INF_PARAMS){
				env.addLocal(s, (i < par_values.length - 1 ? new LispArray(par_values[i .. $]) : par_values[i]));
				break;
			}else
				env.addLocal(s, par_values[i]);
		}
	}else
		throw new BadTypeOfParametersException("Unknown type of parameters for your " ~ type ~ " call - you did some weird shit, didn't you?");
	
	return eval(function_body, env);
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
	testParseWithBothStrings("()", "[]", "()");
	testParseWithBothStrings("(a)", "[a]", "(a)");
	testParseWithBothStrings("(a (b))", "[a, [b]]", "(a (b))");
	testParseWithBothStrings("(a  (     b  )   	)", "[a, [b]]", "(a (b))");
	testParseWithBothStrings("((((()))))", "[[[[[]]]]]", "()");
	testParseWithBothStrings("(a (b (c (d (e)))))", "[a, [b, [c, [d, [e]]]]]", "(a (b (c (d (e)))))");
	
	
	/* sugarToRealLisp ************************************************************************************************/
	void testSugarToRealLisp(string sugar, string lisp){
		assert(sugarToRealLisp(parse(sugar)).toLispString() == lisp);
	}
	testSugarToRealLisp("'()", "(" ~ quoters['\''] ~ " ())");
	testSugarToRealLisp("`()", "(" ~ quoters['`'] ~ " ())");
	testSugarToRealLisp(",()", "(" ~ quoters[','] ~ " ())");
	testSugarToRealLisp("`(1 2 ,(+ 3 4))", "(" ~ quoters['`'] ~ " (1 2 (" ~ quoters[','] ~ " (+ 3 4))))");
	
	
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
	
	/* Eval ***********************************************************************************************************/
	EnvStack env = new EnvStack();
	assert(eval(parse("(q (1 23 (trololo la)))"), env).toLispString() == "(1 23 (trololo la))"); // q/quote
	assert(eval(parse("(cons 1 (q (2 (q 3))))"), env).toLispString() == "(1 2 (q 3))");          // cons
	assert(eval(parse("(qq (1 2 (uq (+ 3 4))))"), env).toLispString() == "(1 2 7)");
	assert(eval(parse("((macro (x) (cdr x)) (id 4))"), env).toLispString() == "(4)");
	assert(eval(parse("((lambda " ~ INF_PARAMS ~ " (car (cdr " ~ INF_PARAMS ~ "))) 1 2 3)"), env).toLispString() == "2");
	assert(eval(parse("((lambda (a " ~ INF_PARAMS ~ ") (cons a (car (cdr " ~ INF_PARAMS ~ ")))) (q first) 1 2 3)"), env).toLispString() == "(first 2)");
	
	//TODO: val
}
































