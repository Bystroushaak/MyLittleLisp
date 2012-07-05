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
	EnvStack es = new EnvStack();
	es.addLocal(new LispSymbol("id"), parse("(lambda x x)"));
	
	writeln(es.toLispString());
	write(">> ");
	
	foreach(string line; lines(stdin)){
		if (line.strip().length == 0){
			write(">> ");
			continue;
		}
		
		try
			writeln(doLisp(line, es).toSugar());
		catch(LispException e)
			writeln(e.msg);
		
		writeln(es);
		write(">> ");
	}
	
	writeln(es);
	
	
	return 0;
}
