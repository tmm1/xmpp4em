/*****************************************************************************

$Id: rubymain.cpp 307 2007-04-28 13:52:16Z blackhedd $

File:     libmain.cpp
Date:     06Apr06

Copyright (C) 2006 by Francis Cianfrocca. All Rights Reserved.
Gmail: garbagecat20

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

*****************************************************************************/


#include <iostream>
#include <stdexcept>
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <ruby.h>


static xmlSAXHandler saxHandler;

/*************************
class RubyXmlPushParser_t
*************************/

class RubyXmlPushParser_t
{
	public:
		RubyXmlPushParser_t (VALUE v);

		void ConsumeData (const char *, int);
		void Close();
		void ScheduleReset();

		void SaxStartDocument();
		void SaxEndDocument();
		void SaxStartElement (const xmlChar*, const xmlChar**);
		void SaxEndElement (const xmlChar*);
		void SaxCharacters (const xmlChar*, int);
		void SaxError();

	private:
		VALUE Myself;
		xmlParserCtxtPtr Context;
		bool bReset;
};



/*****************
rubyStartDocument
*****************/

static void rubyStartDocument (void *ctx)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*) ctx;
	if (!pp)
		throw std::runtime_error ("bad ptr in rubyStartDocument");
	pp->SaxStartDocument();
}

/***************
rubyEndDocument
***************/

static void rubyEndDocument (void *ctx)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*) ctx;
	if (!pp)
		throw std::runtime_error ("bad ptr in rubyEndDocument");
	pp->SaxEndDocument();
}

/****************
rubyStartElement
****************/

static void rubyStartElement (void *ctx, const xmlChar *name, const xmlChar **attrs)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*) ctx;
	if (!pp)
		throw std::runtime_error ("bad ptr in rubyStartElement");
	pp->SaxStartElement (name, attrs);
}

/**************
rubyEndElement
**************/

static void rubyEndElement (void *ctx, const xmlChar *name)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*) ctx;
	if (!pp)
		throw std::runtime_error ("bad ptr in rubyEndElement");
	pp->SaxEndElement (name);
}


/**************
rubyCharacters
**************/

static void rubyCharacters (void *ctx, const xmlChar *val, int len)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*) ctx;
	if (!pp)
		throw std::runtime_error ("bad ptr in rubyCharacters");
	pp->SaxCharacters (val, len);
}

/*********
rubyError
*********/

static void rubyError (void *ctx, const char *msg, ...)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*) ctx;
	if (!pp)
		throw std::runtime_error ("bad ptr in rubyError");
	pp->SaxError();
}


/****************************************
RubyXmlPushParser_t::RubyXmlPushParser_t
****************************************/

RubyXmlPushParser_t::RubyXmlPushParser_t (VALUE v):
	Myself (v),
	bReset (false)
{
	/* Note that we're bypassing the typical convention of passing the
	 * first four bytes of the document to the parser-create function.
	 * Obviously we may not have them yet. We could delay calling this
	 * until the bytes are available but this seems to work fine.
	 * Note that passing in a SAX2 handler means that this parser
	 * will NOT accumulate a document tree, which in turn means we
	 * don't need to worry about freeing the document tree later.
	 * (We will of course need to free the parser itself.)
	 */
	Context = xmlCreatePushParserCtxt (&saxHandler, (void*)this, "", 0, "");
	if (!Context)
		throw std::runtime_error ("no push-parser context");
}


/********************************
RubyXmlPushParser_t::ConsumeData
********************************/

void RubyXmlPushParser_t::ConsumeData (const char *data, int length)
{
	/* Avoid passing more than a few bytes to xmlParseChunk at a time.
	 * We know that at some points (such as while initially determining
	 * the encoding of a new document), the library's internal buffers
	 * are very small.
	 */
	for (int i=0; i < length; i++) {
		if (bReset) {
			// don't send a good-bye kiss to the existing context because it'll
			// probably kick out a malformation error.
			xmlFreeParserCtxt (Context);
			Context = xmlCreatePushParserCtxt (&saxHandler, (void*)this, "", 0, "");
			if (!Context)
				throw std::runtime_error ("no push-parser context");
			bReset = false;
		}
		xmlParseChunk (Context, data+i, 1, 0);
	}
}


/**********************************
RubyXmlPushParser_t::ScheduleReset
**********************************/

void RubyXmlPushParser_t::ScheduleReset()
{
	bReset = true;
}

/**************************
RubyXmlPushParser_t::Close
**************************/

void RubyXmlPushParser_t::Close()
{
	/* We come here automatically when a connection gets an unbind event.
	 * User code can inadvertently cut this off and leak memory by implementing #unbind.
	 * All user code that implements unbind MUST call super within the unbind.
	 *
	 * It's a requirement that this code be called. We're relying on the (hopefully
	 * reliable) fact that a network connection will always get closed sometime.
	 * If this extension ever needs to handle cases that are not matched to a network
	 * connection, then we'll need to arrange some other way for this to get called.
	 */
	xmlParseChunk (Context, "", 0, 1);
	xmlFreeParserCtxt (Context);
	// No need to call xmlFreeDoc (Content->myDoc) because it's always NULL when a SAX handler is present.
}


/*************************************
RubyXmlPushParser_t::SaxStartDocument
*************************************/

void RubyXmlPushParser_t::SaxStartDocument()
{
	rb_funcall (Myself, rb_intern ("start_document"), 0);
}

/***********************************
RubyXmlPushParser_t::SaxEndDocument
***********************************/

void RubyXmlPushParser_t::SaxEndDocument()
{
	/* It's problematical for user code to rely on receiving this event.
	 * If a network peer sends a complete XML document but then sends
	 * nothing more beyond the closing tag of the root element, then
	 * libxml does NOT call endDocument. endDocument will be called in the
	 * following two cases: first, if the caller sends at least one byte beyond
	 * the end of the actual document (this may be a syntactically-valid "Misc"
	 * paragraph at the tail of the document, or the start of a new document, or
	 * erroneous matter); and second, if the remote peer closes the network connection,
	 * which causes us to receive and respond to the unbind event, and in turn
	 * resulting in a call to xmlParseChunk with the terminate flag set.
	 *
	 * This is probably not a problem for a protocol like XMPP, in which the
	 * whole stream is syntactically a single document. But other protocols
	 * might have problems.
	 */
	rb_funcall (Myself, rb_intern ("end_document"), 0);
}

/************************************
RubyXmlPushParser_t::SaxStartElement
************************************/

void RubyXmlPushParser_t::SaxStartElement (const xmlChar *name, const xmlChar **attribs)
{
	if (!name)
		name = (const xmlChar*)"";

	VALUE atts = rb_hash_new();
	if (attribs) {
		while (attribs[0] && attribs[1]) {
			rb_hash_aset (atts, rb_str_new2((const char*)attribs[0]), rb_str_new2((const char*)attribs[1]));
			attribs += 2;
		}
	}
	rb_funcall (Myself, rb_intern ("start_element"), 2, rb_str_new2((const char*)name), atts);
}

/**********************************
RubyXmlPushParser_t::SaxEndElement
**********************************/

void RubyXmlPushParser_t::SaxEndElement (const xmlChar *name)
{
	if (!name)
		name = (const xmlChar*)"";
	rb_funcall (Myself, rb_intern ("end_element"), 1, rb_str_new2((const char*)name));
}

/**********************************
RubyXmlPushParser_t::SaxCharacters
**********************************/

void RubyXmlPushParser_t::SaxCharacters (const xmlChar *name, int length)
{
	if (!name) {
		name = (const xmlChar*)"";
		length = 0;
	}
	rb_funcall (Myself, rb_intern ("characters"), 1, rb_str_new((const char*)name, length));
}

/*****************************
RubyXmlPushParser_t::SaxError
*****************************/

void RubyXmlPushParser_t::SaxError()
{
	int e = xmlCtxtGetLastError (Context)->code;
	if (e == XML_ERR_DOCUMENT_END)
		;
	else {
		rb_funcall (Myself, rb_intern ("error"), 1, INT2FIX (e));
		rb_funcall (Myself, rb_intern ("close_connection"), 0);
	}
}

/***********
t_post_init
***********/

static VALUE t_post_init (VALUE self)
{
	RubyXmlPushParser_t *pp = new RubyXmlPushParser_t (self);
	if (!pp)
		throw std::runtime_error ("no xml push-parser object");

	rb_ivar_set (self, rb_intern ("@xml__push__parser__object"), INT2NUM ((long)pp));
	return Qnil;
}

/**************
t_receive_data
**************/

static VALUE t_receive_data (VALUE self, VALUE data)
{
	int length = NUM2INT (rb_funcall (data, rb_intern ("length"), 0));
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*)(NUM2INT (rb_ivar_get (self, rb_intern ("@xml__push__parser__object"))));
	if (!pp)
		throw std::runtime_error ("bad push-parser object");
	pp->ConsumeData (StringValuePtr (data), length);

	return Qnil;
}

/********
t_unbind
********/

static VALUE t_unbind (VALUE self)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*)(NUM2INT (rb_ivar_get (self, rb_intern ("@xml__push__parser__object"))));
	if (!pp)
		throw std::runtime_error ("no xml push-parser object");
	pp->Close();
	return Qnil;
}


/**************
t_reset_parser
**************/

static VALUE t_reset_parser (VALUE self)
{
	RubyXmlPushParser_t *pp = (RubyXmlPushParser_t*)(NUM2INT (rb_ivar_get (self, rb_intern ("@xml__push__parser__object"))));
	if (!pp)
		throw std::runtime_error ("no xml push-parser object");
	pp->ScheduleReset();

	return Qnil;
}

/****************
t_start_document
****************/

static VALUE t_start_document (VALUE self)
{
	// STUB. Override this in user code if needed.
	return Qnil;
}

/**************
t_end_document
**************/

static VALUE t_end_document (VALUE self)
{
	// STUB. Override this in user code if needed.
	return Qnil;
}

/***************
t_start_element
***************/

static VALUE t_start_element (VALUE self, VALUE name, VALUE attributes)
{
	// STUB. Override this in user code if needed.
	return Qnil;
}

/*************
t_end_element
*************/

static VALUE t_end_element (VALUE self, VALUE name)
{
	// STUB. Override this in user code if needed.
	return Qnil;
}

/************
t_characters
************/

static VALUE t_characters (VALUE self, VALUE data)
{
	// STUB. Override this in user code if needed.
	return Qnil;
}

/*******
t_error
*******/

static VALUE t_error (VALUE self, VALUE code)
{
	// STUB. Override this in user code if needed.
	return Qnil;
}


/**********************
Init_rubyxmlpushparser
**********************/

extern "C" void Init_rubyxmlpushparser()
{
	LIBXML_TEST_VERSION
	#ifndef LIBXML_PUSH_ENABLED
		throw std::runtime_error ("XML push not enabled on this system");
	#endif

	// saxHandler is statically defined and readonly after we initialize it here.
	// We DEPEND on the fact that the C runtime will zero-initialize it.
	saxHandler.startDocument = rubyStartDocument;
	saxHandler.startElement = rubyStartElement;
	saxHandler.endElement = rubyEndElement;
	saxHandler.characters = rubyCharacters;
	saxHandler.endDocument = rubyEndDocument;
	saxHandler.error = rubyError;
	saxHandler.warning = rubyError;

	// Define a module XmlPushParser that can be used standalone and modified,
	// or else included into EventMachine::Connection or a subclass of same.
	// NB that we define #post_init and #unbind here. This means that any user
	// subclass that includes EventMachine::XmlPushParser MUST call super
	// inside subclassed implementations of these two methods.

	VALUE EmModule = rb_define_module ("EventMachine");
	VALUE XmlModule = rb_define_module_under (EmModule, "XmlPushParser");
	rb_define_method (XmlModule, "post_init", (VALUE(*)(...))t_post_init, 0);
	rb_define_method (XmlModule, "receive_data", (VALUE(*)(...))t_receive_data, 1);
	rb_define_method (XmlModule, "unbind", (VALUE(*)(...))t_unbind, 0);
	rb_define_method (XmlModule, "start_document", (VALUE(*)(...))t_start_document, 0);
	rb_define_method (XmlModule, "end_document", (VALUE(*)(...))t_end_document, 0);
	rb_define_method (XmlModule, "start_element", (VALUE(*)(...))t_start_element, 2);
	rb_define_method (XmlModule, "end_element", (VALUE(*)(...))t_end_element, 1);
	rb_define_method (XmlModule, "characters", (VALUE(*)(...))t_characters, 1);
	rb_define_method (XmlModule, "error", (VALUE(*)(...))t_error, 1);
	rb_define_method (XmlModule, "reset_parser", (VALUE(*)(...))t_reset_parser, 0);
}