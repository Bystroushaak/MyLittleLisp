/**
 * 
 * 
 * Author:  Bystroushaak (bystrousak@kitakitsune.org)
 * Version: 0.0.1
 * Date:    
 * 
 * Copyright: 
 *     This work is licensed under a CC BY.
 *     http://creativecommons.org/licenses/by/3.0/
*/
import std.stdio;
import std.getopt;
import std.string;


import mll;


const string HELP_STR    = import("help.txt");
const string VERSION_STR = import("version.txt");



int main(string[] args){
	// parameters for options parsing
	bool help, ver;
	
	// parse options
	try{
		getopt(
			args,
			std.getopt.config.bundling, // onechar shortcuts
			"help|h", &help,
			"version|v", &ver
		);
	}catch(Exception e){
		stderr.writeln(HELP_STR);
		return 1;
	}
	if (help){
		writeln(HELP_STR);
		return 0;
	}
	if (ver){
		writeln(VERSION_STR);
		return 0;
	}
	
	
	
	// here goes program
	
//	Potenciální unittest
	EnvStack es = new EnvStack();
	es.addLocal(new LispSymbol("id"), parse("(lambda x x)"));
	es.addLocal(new LispSymbol("eval"), parse("(lambda x (x))"));
//	es.addLocal(new LispSymbol("plus", [new LispSymbol("a"), new LispSymbol("b")]), parse("(+ a b)"));
//	
	writeln(es);
//	
//	writeln("plus:\t\t", es.find(new LispSymbol("plus")));
//	writeln("plus(x, y):\t", es.find(new LispSymbol("plus", [new LispSymbol("x"), new LispSymbol("y")])));)
	
//	writeln("---\n", eval(parse("((lambda (x) x) plus)"), es), "\n---\n");
//	writeln("---\n", eval(parse("(cons 1 (q (2 3)))"), es), "\n---\n");
//	writeln("---\n", eval(parse("(id)"), es).toLispString(), "\n---\n");
	write(">> ");
	
	foreach(string line; lines(stdin)){
		if (line.strip().length == 0){
			write(">> ");
			continue;
		}
		
		try
			writeln(eval(parse(line), es).toLispString());
		catch(LispException e)
			writeln(e.msg);
		
		writeln(es);
		write(">> ");
	}
	
	writeln(es);
	
	return 0;
}
