/**
* Show all rule categories that are registered
* .
* {code:bash}
* codechecker categories
* {code}
*/
component {
	property name='rulesService' 		inject='rulesService@codechecker-core';
	
	/**
	*
	*/
	function run() {
		categories = rulesService.getCategories().toList();
		print.line( rulesService.getCategories() );
		print.line( rulesService.getRules().map( ( i ) => { return i.category & ' - ' & i.name; } ) );
	}
	
}

