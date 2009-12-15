// ==UserScript==
// @name		rsget.pl helper
// @namespace	http://rsget.pl
// @description	quickly add links to rsget.pl
// @include		http://*/*
// @include		https://*/*
// @include		file://*
// ==/UserScript==

/* lang {{{ */
var translated = {
	location: {
		ca: "Afegeix pàgina actual",
		en: "Add present page",
		es: "Añade página actual",
		pl: "Dodaj obecną stronę",
	},
	links: {
		ca: "Afegeix enllaços",
		en: "Add links",
		es: "Añade enlaces",
		pl: "Dodaj odnośniki",
	},
	specify_location: {
		ca: "Especifica localització de rsget.pl",
		en: "Specify rsget.pl location",
		es: "Especifica ubicación de rsget.pl",
		pl: "Podaj położenie rsget.pl",
	}
};
var lang;
function get_lang()
{
	var m = window.navigator.language.match( /^(.*?)(-.*)?$/ );
	if ( m && m.length > 0 )
		lang = m[1];
}
function get_text( name )
{
	if ( !lang )
		get_lang();

	if ( !translated[ name ] )
		return "invalid text: " + name;
	var tr = translated[ name ];
	if ( tr[ lang ] )
		return tr[ lang ];
	return tr.en;
};
function menu_name( name )
{
	return "rsget.pl: " + get_text( name );
};
/* }}} */

function push_link( links, href )
{
	for ( var i = 0; i < links.length; i++ ) {
		if ( links[ i ] == href )
			return;
	}
	links.push( href );
}

/* add location {{{ */
function push_frame_src( links, el_name )
{
	try {
		var els = w.document.getElementsByTagName( el_name );
		for ( var i = 0; i < els.length; i++ ) {
			var el = els[ i ];
			if ( el.src )
				push_link( links, el.src );
		}
	} catch (e) {};
};
function crawl_frames( links, w )
{
	try {
		push_link( links, w.document.location.href );
	} catch ( e ) {};
	try {
		push_link( links, w.location.href );
	} catch ( e ) {};
	push_frame_src( links, 'iframe' );
	push_frame_src( links, 'frame' );
	try {
		var fel = w.frameElement;
		if ( fel )
			push_link( links, fel.src );
	} catch ( e ) {};

	var frames = w.frames;
	if ( frames ) {
		for ( var i = 0; i < frames.length; i++ ) {
			crawl_frames( links, frames[ i ] );
		}
	}
}
function send_location()
{
	var links = [];
	var w = unsafeWindow;
	crawl_frames( links, w );
	while ( w != w.parent ) {
		w = w.parent;
		crawl_frames( links, w );
	}

	send( links );
}
/* }}} */

/* add links {{{ */
function push_a_href( links, node )
{
	var href = node.getAttribute( 'href' );
	if ( !href )
		return;
	if ( !href.match( /^http:\/\// ) ) {
		var page = document.location.href.match( /(([a-z]+:\/\/[^\/]*).*\/).*/ );
		if ( href.match( /^\// ) )
			href = page[2] + href;
		else
			href = page[1] + href;
	}
	push_link( links, href );
}
function push_from_text( links, text )
{
	text += '';
	var m = text.match( /http:\/\/\S+\/[\w#!:.?+=&%@!\-\/]+/g );
	if ( !m )
		return;
	for ( var i = 0; i < m.length; i++ )
		push_link( links, m[ i ] );
}
function push_from_node( links, node )
{
	if ( !node || !node.nodeName )
		return;
	if ( node.nodeName == 'A' ) {
		push_a_href( links, node );
	} else if ( node.nodeName == '#text' ) {
		push_from_text( links, node.nodeValue );
	}
}

function crawl_nodes( links, node, selection )
{
	while ( node ) {
		if ( selection.containsNode( node, false ) )
			push_from_node( links, node );

		if ( node.firstChild ) {
			node = node.firstChild;
		} else if ( node.nextSibling ) {
			node = node.nextSibling;
		} else {
			do {
				node = node.parentNode;
				if ( ! node )
					return;
			} while ( !node.nextSibling );
			node = node.nextSibling;
		}
	}
}

function send_links()
{
	var range;
	var selection;
	var sel_text;
	try {
		selection = window.getSelection();
		sel_text = selection.toString();
		range = selection.getRangeAt( 0 );
	} catch ( e ) {};
	var links = new Array;


	if ( !range || range.collapsed ) {
		crawl_nodes( links, docbody(),
			{
				containsNode: function ( node, flag ) {
					return true;
				} 
			}
		);
		if ( selection ) {
			selection.selectAllChildren( docbody() );
			sel_text = selection.toString();
			selection.removeAllRanges();
		}
	} else {
		var start = range.startContainer;
		var end = range.endContainer;
		
		if ( start == end ) {
			push_from_text( links,
				start.nodeValue.substring( range.startOffset, range.endOffset )
			);
		} else {
			if ( start.nodeName == 'A' ) {
				push_a_href( links, start );
			} else if ( start.nodeName == '#text' && start.nodeValue ) {
				push_from_text( links, start.nodeValue.substr( range.startOffset ) );
			}
			crawl_nodes( links, start, selection );
			if ( end.nodeName == 'A' ) {
				push_a_href( end );
			} else if ( end.nodeName == '#text' && end.nodeValue) {
				push_from_text( links, end.nodeValue.substr( 0, range.endOffset ) );
			}
		}
	}
	if ( sel_text )
		push_from_text( links, sel_text );

	send( links );
}
/* }}} */

function send( links )
{
	var ltext = links.join( "\n" );
	try {
		window.setTimeout( send_text, 100, ltext );
	} catch (e) {
		GM_log( "Error: " + e );
		send_text( ltext );
	}
}

function docbody()
{
	// no document.body in XHTML
	return document.getElementsByTagName( 'body' )[0];
}
var server;
function rm_node( node )
{
	node.parentNode.removeChild( node );
}
function send_text( text )
{
	var uri = server + "add";

	var form = document.createElement( 'form' );
	form.setAttribute( 'action', uri );
	form.setAttribute( 'method', 'POST' );
	form.setAttribute( 'target', '_blank' );

	var ar = document.createElement( 'textarea' );
	ar.setAttribute( 'name', 'links' );
	ar.value = text;
	form.appendChild( ar );
	try {
		docbody().appendChild( form );
		window.setTimeout( rm_node, 1000, form );
		form.submit();
	} catch (e) {
		GM_log( "Error: " + e );
		var get = uri + "?links=" + escape( text );
		GM_openInTab( get );
	}
}

(function()
 {
	server = GM_getValue( "server" );
	if ( server == null ) {
		server = prompt( get_text( "specify_location" ), "http://localhost:5666/" );
		GM_setValue( "server", server );
	}

	GM_registerMenuCommand( menu_name("location"), send_location );
	GM_registerMenuCommand( menu_name("links"), send_links );
})();

// vim: ts=4:sw=4:fdm=marker
