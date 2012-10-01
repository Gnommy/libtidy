/** @file tidy.h - Defines HTML Tidy API implemented by tidy library.

  Public interface is const-correct and doesn't explicitly depend
  on any globals.  Thus, thread-safety may be introduced w/out
  changing the interface.

  Looking ahead to a C++ wrapper, C functions always pass 
  this-equivalent as 1st arg.


  Copyright (c) 1998-2008 World Wide Web Consortium
  (Massachusetts Institute of Technology, European Research 
  Consortium for Informatics and Mathematics, Keio University).
  All Rights Reserved.

  CVS Info :

    $Author: arnaud02 $ 
    $Date: 2008/04/22 11:00:42 $ 
    $Revision: 1.22 $ 

  Contributing Author(s):

     Dave Raggett <dsr@w3.org>

  The contributing author(s) would like to thank all those who
  helped with testing, bug fixes and suggestions for improvements. 
  This wouldn't have been possible without your help.

  COPYRIGHT NOTICE:
 
  This software and documentation is provided "as is," and
  the copyright holders and contributing author(s) make no
  representations or warranties, express or implied, including
  but not limited to, warranties of merchantability or fitness
  for any particular purpose or that the use of the software or
  documentation will not infringe any third party patents,
  copyrights, trademarks or other rights. 

  The copyright holders and contributing author(s) will not be held
  liable for any direct, indirect, special or consequential damages
  arising out of any use of the software or documentation, even if
  advised of the possibility of such damage.

  Permission is hereby granted to use, copy, modify, and distribute
  this source code, or portions hereof, documentation and executables,
  for any purpose, without fee, subject to the following restrictions:

  1. The origin of this source code must not be misrepresented.
  2. Altered versions must be plainly marked as such and must
     not be misrepresented as being the original source.
  3. This Copyright notice may not be removed or altered from any
     source or altered source distribution.
 
  The copyright holders and contributing author(s) specifically
  permit, without fee, and encourage the use of this source code
  as a component for supporting the Hypertext Markup Language in
  commercial products. If you use this source code in a product,
  acknowledgment is not required but would be appreciated.


  Created 2001-05-20 by Charles Reitzel
  Updated 2002-07-01 by Charles Reitzel - 1st Implementation

*/
module deimos.libtidy_.tidy;

private import deimos.libtidy_.tidyenum;
private import core.stdc.stdio;

extern(C):

/** @defgroup Opaque Opaque Types
**
** Cast to implementation types within lib.
** Reduces inter-dependencies/conflicts w/ application code.
** @{
*/

/** @struct TidyDoc
**  Opaque document datatype
*/
typedef void* TidyDoc;

/** @struct TidyOption
**  Opaque option datatype
*/
typedef void* TidyOption;

/** @struct TidyNode
**  Opaque node datatype
*/
typedef void* TidyNode;

/** @struct TidyAttr
**  Opaque attribute datatype
*/
typedef void* TidyAttr;

/** @struct TidyIterator
**  Opaque attribute datatype
*/
typedef void* TidyIterator;

/** @} end Opaque group */

/** TidyBuffer - A chunk of memory */
struct TidyBuffer 
{
    void* allocator;  /**< Memory allocator */
    byte* bp;           /**< Pointer to bytes */
    uint  size;         /**< # bytes currently in use */
    uint  allocated;    /**< # bytes allocated */ 
    uint  next;         /**< Offset of current input position */
};

/** @defgroup Memory  Memory Allocation
**
** Tidy uses a user provided allocator for all
** memory allocations.  If this allocator is
** not provided, then a default allocator is
** used which simply wraps standard C malloc/free
** calls.  These wrappers call the panic function
** upon any failure.  The default panic function
** prints an out of memory message to stderr, and
** calls exit(2).
**
** For applications in which it is unacceptable to
** abort in the case of memory allocation, then the
** panic function can be replaced with one which
** longjmps() out of the tidy code.  For this to
** clean up completely, you should be careful not
** to use any tidy methods that open files as these
** will not be closed before panic() is called.
**
** TODO: associate file handles with tidyDoc and
** ensure that tidyDocRelease() can close them all.
**
** Calling the withAllocator() family (
** tidyCreateWithAllocator, tidyBufInitWithAllocator,
** tidyBufAllocWithAllocator) allow settings custom
** allocators).
**
** All parts of the document use the same allocator.
** Calls that require a user provided buffer can
** optionally use a different allocator.
**
** For reference in designing a plug-in allocator,
** most allocations made by tidy are less than 100
** bytes, corresponding to attribute names/values, etc.
**
** There is also an additional class of much larger
** allocations which are where most of the data from
** the lexer is stored.  (It is not currently possible
** to use a separate allocator for the lexer, this
** would be a useful extension).
**
** In general, approximately 1/3rd of the memory
** used by tidy is freed during the parse, so if
** memory usage is an issue then an allocator that 
** can reuse this memory is a good idea.
**
** @{
*/

/** Prototype for the allocator's function table */
//struct _TidyAllocatorVtbl;
/** The allocators function table */
//typedef _TidyAllocatorVtbl TidyAllocatorVtbl;

/** Prototype for the allocator */
//struct _TidyAllocator;
/** The allocator **/
//typedef _TidyAllocator TidyAllocator;

/** An allocator's function table.  All functions here must
    be provided.
 */
struct TidyAllocatorVtbl
{
    /** Called to allocate a block of nBytes of memory */
    void* function( TidyAllocator *self, size_t nBytes ) alloc;
    /** Called to resize (grow, in general) a block of memory.
        Must support being called with NULL.
    */
    void* function( TidyAllocator *self, void *block, size_t nBytes ) realloc;
    /** Called to free a previously allocated block of memory */
    void function( TidyAllocator *self, void *block) free;
    /** Called when a panic condition is detected.  Must support
        block == NULL.  This function is not called if either alloc 
        or realloc fails; it is up to the allocator to do this.
        Currently this function can only be called if an error is
        detected in the tree integrity via the internal function
        CheckNodeIntegrity().  This is a situation that can
        only arise in the case of a programming error in tidylib.
        You can turn off node integrity checking by defining
        the constant NO_NODE_INTEGRITY_CHECK during the build.
    **/
    void function( TidyAllocator *self, const(char)* msg ) panic;
};

/** An allocator.  To create your own allocator, do something like
    the following:
    
    typedef struct _MyAllocator {
       TidyAllocator base;
       ...other custom allocator state...
    } MyAllocator;
    
    void* MyAllocator_alloc(TidyAllocator *base, void *block, size_t nBytes)
    {
        MyAllocator *self = (MyAllocator*)base;
        ...
    }
    (etc)

    static const TidyAllocatorVtbl MyAllocatorVtbl = {
        MyAllocator_alloc,
        MyAllocator_realloc,
        MyAllocator_free,
        MyAllocator_panic
    };

    myAllocator allocator;
    TidyDoc doc;

    allocator.base.vtbl = &amp;MyAllocatorVtbl;
    ...initialise allocator specific state...
    doc = tidyCreateWithAllocator(&allocator);
    ...

    Although this looks slightly long winded, the advantage is that to create
    a custom allocator you simply need to set the vtbl pointer correctly.
    The vtbl itself can reside in static/global data, and hence does not
    need to be initialised each time an allocator is created, and furthermore
    the memory is shared amongst all created allocators.
*/
struct TidyAllocator
{
    const TidyAllocatorVtbl *vtbl;
};

/** Callback for "malloc" replacement */
typedef void* function( size_t len ) TidyMalloc;
/** Callback for "realloc" replacement */
typedef void* function( void* buf, size_t len ) TidyRealloc;
/** Callback for "free" replacement */
typedef void  function( void* buf ) TidyFree;
/** Callback for "out of memory" panic state */
typedef void  function( const(char)* mssg ) TidyPanic;


/** Give Tidy a malloc() replacement */
bool tidySetMallocCall( TidyMalloc fmalloc );
/** Give Tidy a realloc() replacement */
bool tidySetReallocCall( TidyRealloc frealloc );
/** Give Tidy a free() replacement */
bool tidySetFreeCall( TidyFree ffree );
/** Give Tidy an "out of memory" handler */
bool tidySetPanicCall( TidyPanic fpanic );

/** @} end Memory group */

/** @defgroup Basic Basic Operations
**
** Tidy public interface
**
** Several functions return an integer document status:
**
** <pre>
** 0    -> SUCCESS
** >0   -> 1 == TIDY WARNING, 2 == TIDY ERROR
** <0   -> SEVERE ERROR
** </pre>
** 
The following is a short example program.

<pre>
#include &lt;tidy.h&gt;
#include &lt;buffio.h&gt;
#include &lt;stdio.h&gt;
#include &lt;errno.h&gt;


int main(int argc, char **argv )
{
  const char* input = "&lt;title&gt;Foo&lt;/title&gt;&lt;p&gt;Foo!";
  TidyBuffer output;
  TidyBuffer errbuf;
  int rc = -1;
  bool ok;

  TidyDoc tdoc = tidyCreate();                     // Initialize "document"
  tidyBufInit( &amp;output );
  tidyBufInit( &amp;errbuf );
  printf( "Tidying:\t\%s\\n", input );

  ok = tidyOptSetbool( tdoc, TidyXhtmlOut, yes );  // Convert to XHTML
  if ( ok )
    rc = tidySetErrorBuffer( tdoc, &amp;errbuf );      // Capture diagnostics
  if ( rc &gt;= 0 )
    rc = tidyParseString( tdoc, input );           // Parse the input
  if ( rc &gt;= 0 )
    rc = tidyCleanAndRepair( tdoc );               // Tidy it up!
  if ( rc &gt;= 0 )
    rc = tidyRunDiagnostics( tdoc );               // Kvetch
  if ( rc &gt; 1 )                                    // If error, force output.
    rc = ( tidyOptSetbool(tdoc, TidyForceOutput, yes) ? rc : -1 );
  if ( rc &gt;= 0 )
    rc = tidySaveBuffer( tdoc, &amp;output );          // Pretty Print

  if ( rc &gt;= 0 )
  {
    if ( rc &gt; 0 )
      printf( "\\nDiagnostics:\\n\\n\%s", errbuf.bp );
    printf( "\\nAnd here is the result:\\n\\n\%s", output.bp );
  }
  else
    printf( "A severe error (\%d) occurred.\\n", rc );

  tidyBufFree( &amp;output );
  tidyBufFree( &amp;errbuf );
  tidyRelease( tdoc );
  return rc;
}
</pre>
** @{
*/

TidyDoc     tidyCreate();
TidyDoc     tidyCreateWithAllocator( TidyAllocator *allocator );
void         tidyRelease( TidyDoc tdoc );

/** Let application store a chunk of data w/ each Tidy instance.
**  Useful for callbacks.
*/
void        tidySetAppData( TidyDoc tdoc, void* appData );

/** Get application data set previously */
void*       tidyGetAppData( TidyDoc tdoc );

/** Get release date (version) for current library */
const(char)*     tidyReleaseDate();

/* Diagnostics and Repair
*/

/** Get status of current document. */
int         tidyStatus( TidyDoc tdoc );

/** Detected HTML version: 0, 2, 3 or 4 */
int         tidyDetectedHtmlVersion( TidyDoc tdoc );

/** Input is XHTML? */
bool        tidyDetectedXhtml( TidyDoc tdoc );

/** Input is generic XML (not HTML or XHTML)? */
bool        tidyDetectedGenericXml( TidyDoc tdoc );

/** Number of Tidy errors encountered.  If > 0, output is suppressed
**  unless TidyForceOutput is set.
*/
uint        tidyErrorCount( TidyDoc tdoc );

/** Number of Tidy warnings encountered. */
uint        tidyWarningCount( TidyDoc tdoc );

/** Number of Tidy accessibility warnings encountered. */
uint        tidyAccessWarningCount( TidyDoc tdoc );

/** Number of Tidy configuration errors encountered. */
uint        tidyConfigErrorCount( TidyDoc tdoc );

/* Get/Set configuration options
*/
/** Load an ASCII Tidy configuration file */
int         tidyLoadConfig( TidyDoc tdoc, const(char)* configFile );

/** Load a Tidy configuration file with the specified character encoding */
int         tidyLoadConfigEnc( TidyDoc tdoc, const(char)* configFile,
                                                     const(char)* charenc );

bool        tidyFileExists( TidyDoc tdoc, const(char)* filename );


/** Set the input/output character encoding for parsing markup.
**  Values include: ascii, latin1, raw, utf8, iso2022, mac,
**  win1252, utf16le, utf16be, utf16, big5 and shiftjis.  Case in-sensitive.
*/
int         tidySetCharEncoding( TidyDoc tdoc, const(char)* encnam );

/** Set the input encoding for parsing markup.
** As for tidySetCharEncoding but only affects the input encoding
**/
int         tidySetInCharEncoding( TidyDoc tdoc, const(char)* encnam );

/** Set the output encoding.
**/
int         tidySetOutCharEncoding( TidyDoc tdoc, const(char)* encnam );

/** @} end Basic group */


/** @defgroup Configuration Configuration Options
**
** Functions for getting and setting Tidy configuration options.
** @{
*/

/** Applications using TidyLib may want to augment command-line and
**  configuration file options.  Setting this callback allows an application 
**  developer to examine command-line and configuration file options after
**  TidyLib has examined them and failed to recognize them.
**/

typedef bool (*TidyOptCallback)( const(char)* option, const(char)* value );

bool          tidySetOptionCallback( TidyDoc tdoc, TidyOptCallback pOptCallback );

/** Get option ID by name */
TidyOptionId  tidyOptGetIdForName( const(char)* optnam );

/** Get iterator for list of option */
/** 
Example:
<pre>
TidyIterator itOpt = tidyGetOptionList( tdoc );
while ( itOpt )
{
  TidyOption opt = tidyGetNextOption( tdoc, &itOpt );
  .. get/set option values ..
}
</pre>
*/

TidyIterator  tidyGetOptionList( TidyDoc tdoc );
/** Get next Option */
TidyOption    tidyGetNextOption( TidyDoc tdoc, TidyIterator* pos );

/** Lookup option by ID */
TidyOption    tidyGetOption( TidyDoc tdoc, TidyOptionId optId );
/** Lookup option by name */
TidyOption    tidyGetOptionByName( TidyDoc tdoc, const(char)* optnam );

/** Get ID of given Option */
TidyOptionId  tidyOptGetId( TidyOption opt );

/** Get name of given Option */
const(char)*       tidyOptGetName( TidyOption opt );

/** Get datatype of given Option */
TidyOptionType tidyOptGetType( TidyOption opt );

/** Is Option read-only? */
bool          tidyOptIsReadOnly( TidyOption opt );

/** Get category of given Option */
TidyConfigCategory tidyOptGetCategory( TidyOption opt );

/** Get default value of given Option as a string */
const(char)*       tidyOptGetDefault( TidyOption opt );

/** Get default value of given Option as an unsigned integer */
ulong         tidyOptGetDefaultInt( TidyOption opt );

/** Get default value of given Option as a boolean value */
bool          tidyOptGetDefaultbool( TidyOption opt );

/** Iterate over Option "pick list" */
TidyIterator  tidyOptGetPickList( TidyOption opt );
/** Get next string value of Option "pick list" */
const(char)*       tidyOptGetNextPick( TidyOption opt, TidyIterator* pos );

/** Get current Option value as a string */
const(char)*       tidyOptGetValue( TidyDoc tdoc, TidyOptionId optId );
/** Set Option value as a string */
bool          tidyOptSetValue( TidyDoc tdoc, TidyOptionId optId, const(char)* val );
/** Set named Option value as a string.  Good if not sure of type. */
bool          tidyOptParseValue( TidyDoc tdoc, const(char)* optnam, const(char)* val );

/** Get current Option value as an integer */
ulong         tidyOptGetInt( TidyDoc tdoc, TidyOptionId optId );
/** Set Option value as an integer */
bool          tidyOptSetInt( TidyDoc tdoc, TidyOptionId optId, ulong val );

/** Get current Option value as a boolean flag */
bool          tidyOptGetbool( TidyDoc tdoc, TidyOptionId optId );
/** Set Option value as a boolean flag */
bool          tidyOptSetbool( TidyDoc tdoc, TidyOptionId optId, bool val );

/** Reset option to default value by ID */
bool          tidyOptResetToDefault( TidyDoc tdoc, TidyOptionId opt );
/** Reset all options to their default values */
bool          tidyOptResetAllToDefault( TidyDoc tdoc );

/** Take a snapshot of current config settings */
bool          tidyOptSnapshot( TidyDoc tdoc );
/** Reset config settings to snapshot (after document processing) */
bool          tidyOptResetToSnapshot( TidyDoc tdoc );

/** Any settings different than default? */
bool          tidyOptDiffThanDefault( TidyDoc tdoc );
/** Any settings different than snapshot? */
bool          tidyOptDiffThanSnapshot( TidyDoc tdoc );

/** Copy current configuration settings from one document to another */
bool          tidyOptCopyConfig( TidyDoc tdocTo, TidyDoc tdocFrom );

/** Get character encoding name.  Used with TidyCharEncoding,
**  TidyOutCharEncoding, TidyInCharEncoding */
const(char)*       tidyOptGetEncName( TidyDoc tdoc, TidyOptionId optId );

/** Get current pick list value for option by ID.  Useful for enum types. */
const(char)*       tidyOptGetCurrPick( TidyDoc tdoc, TidyOptionId optId);

/** Iterate over user declared tags */
TidyIterator  tidyOptGetDeclTagList( TidyDoc tdoc );
/** Get next declared tag of specified type: TidyInlineTags, TidyBlockTags,
**  TidyEmptyTags, TidyPreTags */
const(char)*       tidyOptGetNextDeclTag( TidyDoc tdoc, 
                                                          TidyOptionId optId,
                                                          TidyIterator* iter );
/** Get option description */
const(char)*       tidyOptGetDoc( TidyDoc tdoc, TidyOption opt );

/** Iterate over a list of related options */
TidyIterator  tidyOptGetDocLinksList( TidyDoc tdoc,
                                                  TidyOption opt );
/** Get next related option */
TidyOption    tidyOptGetNextDocLinks( TidyDoc tdoc,
                                                  TidyIterator* pos );

/** @} end Configuration group */

/** @defgroup IO  I/O and Messages
**
** By default, Tidy will define, create and use 
** instances of input and output handlers for 
** standard C buffered I/O (i.e. FILE* stdin,
** FILE* stdout and FILE* stderr for content
** input, content output and diagnostic output,
** respectively.  A FILE* cfgFile input handler
** will be used for config files.  Command line
** options will just be set directly.
**
** @{
*/

/*****************
   Input Source
*****************/
/** Input Callback: get next byte of input */
typedef int  (*TidyGetByteFunc)( void* sourceData );

/** Input Callback: unget a byte of input */
typedef void (*TidyUngetByteFunc)( void* sourceData, byte bt );

/** Input Callback: is end of input? */
typedef bool (*TidyEOFFunc)( void* sourceData );

/** End of input "character" */
//#define EndOfStream (~0u)

/** TidyInputSource - Delivers raw bytes of input
*/
struct TidyInputSource
{
  /* Instance data */
  void*               sourceData;  /**< Input context.  Passed to callbacks */

  /* Methods */
  TidyGetByteFunc     getByte;     /**< Pointer to "get byte" callback */
  TidyUngetByteFunc   ungetByte;   /**< Pointer to "unget" callback */
  TidyEOFFunc         eof;         /**< Pointer to "eof" callback */
};

/** Facilitates user defined source by providing
**  an entry point to marshal pointers-to-functions.
**  Needed by .NET and possibly other language bindings.
*/
bool tidyInitSource( TidyInputSource*  source,
                                          void*             srcData,
                                          TidyGetByteFunc   gbFunc,
                                          TidyUngetByteFunc ugbFunc,
                                          TidyEOFFunc       endFunc );

/** Helper: get next byte from input source */
uint tidyGetByte( TidyInputSource* source );

/** Helper: unget byte back to input source */
void tidyUngetByte( TidyInputSource* source, uint byteValue );

/** Helper: check if input source at end */
bool tidyIsEOF( TidyInputSource* source );


/****************
   Output Sink
****************/
/** Output callback: send a byte to output */
typedef void (*TidyPutByteFunc)( void* sinkData, byte bt );


/** TidyOutputSink - accepts raw bytes of output
*/
struct TidyOutputSink
{
  /* Instance data */
  void*               sinkData;  /**< Output context.  Passed to callbacks */

  /* Methods */
  TidyPutByteFunc     putByte;   /**< Pointer to "put byte" callback */
};

/** Facilitates user defined sinks by providing
**  an entry point to marshal pointers-to-functions.
**  Needed by .NET and possibly other language bindings.
*/
bool tidyInitSink( TidyOutputSink* sink, 
                                        void*           snkData,
                                        TidyPutByteFunc pbFunc );

/** Helper: send a byte to output */
void tidyPutByte( TidyOutputSink* sink, uint byteValue );


/** Callback to filter messages by diagnostic level:
**  info, warning, etc.  Just set diagnostic output 
**  handler to redirect all diagnostics output.  Return true
**  to proceed with output, false to cancel.
*/
typedef bool (*TidyReportFilter)( TidyDoc tdoc, TidyReportLevel lvl,
                                           uint line, uint col, const(char)* mssg );

/** Give Tidy a filter callback to use */
bool    tidySetReportFilter( TidyDoc tdoc,
                                                  TidyReportFilter filtCallback );

/** Set error sink to named file */
FILE*   tidySetErrorFile( TidyDoc tdoc, const(char)* errfilnam );
/** Set error sink to given buffer */
int     tidySetErrorBuffer( TidyDoc tdoc, TidyBuffer* errbuf );
/** Set error sink to given generic sink */
int     tidySetErrorSink( TidyDoc tdoc, TidyOutputSink* sink );

/** @} end IO group */

/* TODO: Catalog all messages for easy translation
const(char)*     tidyLookupMessage( int errorNo );
*/



/** @defgroup Parse Document Parse
**
** Parse markup from a given input source.  String and filename 
** functions added for convenience.  HTML/XHTML version determined
** from input.
** @{
*/

/** Parse markup in named file */
int         tidyParseFile( TidyDoc tdoc, const(char)* filename );

/** Parse markup from the standard input */
int         tidyParseStdin( TidyDoc tdoc );

/** Parse markup in given string */
int         tidyParseString( TidyDoc tdoc, const(char)* content );

/** Parse markup in given buffer */
int         tidyParseBuffer( TidyDoc tdoc, TidyBuffer* buf );

/** Parse markup in given generic input source */
int         tidyParseSource( TidyDoc tdoc, TidyInputSource* source);

/** @} End Parse group */


/** @defgroup Clean Diagnostics and Repair
**
** @{
*/
/** Execute configured cleanup and repair operations on parsed markup */
int         tidyCleanAndRepair( TidyDoc tdoc );

/** Run configured diagnostics on parsed and repaired markup. 
**  Must call tidyCleanAndRepair() first.
*/
int         tidyRunDiagnostics( TidyDoc tdoc );

/** @} end Clean group */


/** @defgroup Save Document Save Functions
**
** Save currently parsed document to the given output sink.  File name
** and string/buffer functions provided for convenience.
** @{
*/

/** Save to named file */
int         tidySaveFile( TidyDoc tdoc, const(char)* filename );

/** Save to standard output (FILE*) */
int         tidySaveStdout( TidyDoc tdoc );

/** Save to given TidyBuffer object */
int         tidySaveBuffer( TidyDoc tdoc, TidyBuffer* buf );

/** Save document to application buffer.  If buffer is not big enough,
**  ENOMEM will be returned and the necessary buffer size will be placed
**  in *buflen.
*/
int         tidySaveString( TidyDoc tdoc,
                                                 const(char)* buffer, uint* buflen );

/** Save to given generic output sink */
int         tidySaveSink( TidyDoc tdoc, TidyOutputSink* sink );

/** @} end Save group */


/** @addtogroup Basic
** @{
*/
/** Save current settings to named file.
    Only non-default values are written. */
int         tidyOptSaveFile( TidyDoc tdoc, const(char)* cfgfil );

/** Save current settings to given output sink.
    Only non-default values are written. */
int         tidyOptSaveSink( TidyDoc tdoc, TidyOutputSink* sink );


/* Error reporting functions 
*/

/** Write more complete information about errors to current error sink. */
void        tidyErrorSummary( TidyDoc tdoc );

/** Write more general information about markup to current error sink. */
void        tidyGeneralInfo( TidyDoc tdoc );

/** @} end Basic group (again) */


/** @defgroup Tree Document Tree
**
** A parsed and, optionally, repaired document is
** represented by Tidy as a Tree, much like a W3C DOM.
** This tree may be traversed using these functions.
** The following snippet gives a basic idea how these
** functions can be used.
**
<pre>
void dumpNode( TidyNode tnod, int indent )
{
  TidyNode child;

  for ( child = tidyGetChild(tnod); child; child = tidyGetNext(child) )
  {
    const(char)* name;
    switch ( tidyNodeGetType(child) )
    {
    case TidyNode_Root:       name = "Root";                    break;
    case TidyNode_DocType:    name = "DOCTYPE";                 break;
    case TidyNode_Comment:    name = "Comment";                 break;
    case TidyNode_ProcIns:    name = "Processing Instruction";  break;
    case TidyNode_Text:       name = "Text";                    break;
    case TidyNode_CDATA:      name = "CDATA";                   break;
    case TidyNode_Section:    name = "XML Section";             break;
    case TidyNode_Asp:        name = "ASP";                     break;
    case TidyNode_Jste:       name = "JSTE";                    break;
    case TidyNode_Php:        name = "PHP";                     break;
    case TidyNode_XmlDecl:    name = "XML Declaration";         break;

    case TidyNode_Start:
    case TidyNode_End:
    case TidyNode_StartEnd:
    default:
      name = tidyNodeGetName( child );
      break;
    }
    assert( name != NULL );
    printf( "\%*.*sNode: \%s\\n", indent, indent, " ", name );
    dumpNode( child, indent + 4 );
  }
}

void dumpDoc( TidyDoc tdoc )
{
  dumpNode( tidyGetRoot(tdoc), 0 );
}

void dumpBody( TidyDoc tdoc )
{
  dumpNode( tidyGetBody(tdoc), 0 );
}
</pre>

@{

*/

TidyNode    tidyGetRoot( TidyDoc tdoc );
TidyNode    tidyGetHtml( TidyDoc tdoc );
TidyNode    tidyGetHead( TidyDoc tdoc );
TidyNode    tidyGetBody( TidyDoc tdoc );

/* parent / child */
TidyNode    tidyGetParent( TidyNode tnod );
TidyNode    tidyGetChild( TidyNode tnod );

/* siblings */
TidyNode    tidyGetNext( TidyNode tnod );
TidyNode    tidyGetPrev( TidyNode tnod );

/* Null for non-element nodes and all pure HTML
const(char)*     tidyNodeNsLocal( TidyNode tnod );
const(char)*     tidyNodeNsPrefix( TidyNode tnod );
const(char)*     tidyNodeNsUri( TidyNode tnod );
*/

/* Iterate over attribute values */
TidyAttr    tidyAttrFirst( TidyNode tnod );
TidyAttr    tidyAttrNext( TidyAttr tattr );

const(char)*     tidyAttrName( TidyAttr tattr );
const(char)*     tidyAttrValue( TidyAttr tattr );

/* Null for pure HTML
const(char)*     tidyAttrNsLocal( TidyAttr tattr );
const(char)*     tidyAttrNsPrefix( TidyAttr tattr );
const(char)*     tidyAttrNsUri( TidyAttr tattr );
*/

/** @} end Tree group */


/** @defgroup NodeAsk Node Interrogation
**
** Get information about any givent node.
** @{
*/

/* Node info */
TidyNodeType tidyNodeGetType( TidyNode tnod );
const(char)*     tidyNodeGetName( TidyNode tnod );

bool tidyNodeIsText( TidyNode tnod );
bool tidyNodeIsProp( TidyDoc tdoc, TidyNode tnod );
bool tidyNodeIsHeader( TidyNode tnod ); /* h1, h2, ... */

bool tidyNodeHasText( TidyDoc tdoc, TidyNode tnod );
bool tidyNodeGetText( TidyDoc tdoc, TidyNode tnod, TidyBuffer* buf );

/* Copy the unescaped value of this node into the given TidyBuffer as UTF-8 */
bool tidyNodeGetValue( TidyDoc tdoc, TidyNode tnod, TidyBuffer* buf );

TidyTagId tidyNodeGetId( TidyNode tnod );

uint tidyNodeLine( TidyNode tnod );
uint tidyNodeColumn( TidyNode tnod );

/** @defgroup NodeIsElementName Deprecated node interrogation per TagId
**
** @deprecated The functions tidyNodeIs{ElementName} are deprecated and 
** should be replaced by tidyNodeGetId.
** @{
*/
bool tidyNodeIsHTML( TidyNode tnod );
bool tidyNodeIsHEAD( TidyNode tnod );
bool tidyNodeIsTITLE( TidyNode tnod );
bool tidyNodeIsBASE( TidyNode tnod );
bool tidyNodeIsMETA( TidyNode tnod );
bool tidyNodeIsBODY( TidyNode tnod );
bool tidyNodeIsFRAMESET( TidyNode tnod );
bool tidyNodeIsFRAME( TidyNode tnod );
bool tidyNodeIsIFRAME( TidyNode tnod );
bool tidyNodeIsNOFRAMES( TidyNode tnod );
bool tidyNodeIsHR( TidyNode tnod );
bool tidyNodeIsH1( TidyNode tnod );
bool tidyNodeIsH2( TidyNode tnod );
bool tidyNodeIsPRE( TidyNode tnod );
bool tidyNodeIsLISTING( TidyNode tnod );
bool tidyNodeIsP( TidyNode tnod );
bool tidyNodeIsUL( TidyNode tnod );
bool tidyNodeIsOL( TidyNode tnod );
bool tidyNodeIsDL( TidyNode tnod );
bool tidyNodeIsDIR( TidyNode tnod );
bool tidyNodeIsLI( TidyNode tnod );
bool tidyNodeIsDT( TidyNode tnod );
bool tidyNodeIsDD( TidyNode tnod );
bool tidyNodeIsTABLE( TidyNode tnod );
bool tidyNodeIsCAPTION( TidyNode tnod );
bool tidyNodeIsTD( TidyNode tnod );
bool tidyNodeIsTH( TidyNode tnod );
bool tidyNodeIsTR( TidyNode tnod );
bool tidyNodeIsCOL( TidyNode tnod );
bool tidyNodeIsCOLGROUP( TidyNode tnod );
bool tidyNodeIsBR( TidyNode tnod );
bool tidyNodeIsA( TidyNode tnod );
bool tidyNodeIsLINK( TidyNode tnod );
bool tidyNodeIsB( TidyNode tnod );
bool tidyNodeIsI( TidyNode tnod );
bool tidyNodeIsSTRONG( TidyNode tnod );
bool tidyNodeIsEM( TidyNode tnod );
bool tidyNodeIsBIG( TidyNode tnod );
bool tidyNodeIsSMALL( TidyNode tnod );
bool tidyNodeIsPARAM( TidyNode tnod );
bool tidyNodeIsOPTION( TidyNode tnod );
bool tidyNodeIsOPTGROUP( TidyNode tnod );
bool tidyNodeIsIMG( TidyNode tnod );
bool tidyNodeIsMAP( TidyNode tnod );
bool tidyNodeIsAREA( TidyNode tnod );
bool tidyNodeIsNOBR( TidyNode tnod );
bool tidyNodeIsWBR( TidyNode tnod );
bool tidyNodeIsFONT( TidyNode tnod );
bool tidyNodeIsLAYER( TidyNode tnod );
bool tidyNodeIsSPACER( TidyNode tnod );
bool tidyNodeIsCENTER( TidyNode tnod );
bool tidyNodeIsSTYLE( TidyNode tnod );
bool tidyNodeIsSCRIPT( TidyNode tnod );
bool tidyNodeIsNOSCRIPT( TidyNode tnod );
bool tidyNodeIsFORM( TidyNode tnod );
bool tidyNodeIsTEXTAREA( TidyNode tnod );
bool tidyNodeIsBLOCKQUOTE( TidyNode tnod );
bool tidyNodeIsAPPLET( TidyNode tnod );
bool tidyNodeIsOBJECT( TidyNode tnod );
bool tidyNodeIsDIV( TidyNode tnod );
bool tidyNodeIsSPAN( TidyNode tnod );
bool tidyNodeIsINPUT( TidyNode tnod );
bool tidyNodeIsQ( TidyNode tnod );
bool tidyNodeIsLABEL( TidyNode tnod );
bool tidyNodeIsH3( TidyNode tnod );
bool tidyNodeIsH4( TidyNode tnod );
bool tidyNodeIsH5( TidyNode tnod );
bool tidyNodeIsH6( TidyNode tnod );
bool tidyNodeIsADDRESS( TidyNode tnod );
bool tidyNodeIsXMP( TidyNode tnod );
bool tidyNodeIsSELECT( TidyNode tnod );
bool tidyNodeIsBLINK( TidyNode tnod );
bool tidyNodeIsMARQUEE( TidyNode tnod );
bool tidyNodeIsEMBED( TidyNode tnod );
bool tidyNodeIsBASEFONT( TidyNode tnod );
bool tidyNodeIsISINDEX( TidyNode tnod );
bool tidyNodeIsS( TidyNode tnod );
bool tidyNodeIsSTRIKE( TidyNode tnod );
bool tidyNodeIsU( TidyNode tnod );
bool tidyNodeIsMENU( TidyNode tnod );

/** @} End NodeIsElementName group */

/** @} End NodeAsk group */


/** @defgroup Attribute Attribute Interrogation
**
** Get information about any given attribute.
** @{
*/

TidyAttrId tidyAttrGetId( TidyAttr tattr );
bool tidyAttrIsEvent( TidyAttr tattr );
bool tidyAttrIsProp( TidyAttr tattr );

/** @defgroup AttrIsAttributeName Deprecated attribute interrogation per AttrId
**
** @deprecated The functions  tidyAttrIs{AttributeName} are deprecated and 
** should be replaced by tidyAttrGetId.
** @{
*/
bool tidyAttrIsHREF( TidyAttr tattr );
bool tidyAttrIsSRC( TidyAttr tattr );
bool tidyAttrIsID( TidyAttr tattr );
bool tidyAttrIsNAME( TidyAttr tattr );
bool tidyAttrIsSUMMARY( TidyAttr tattr );
bool tidyAttrIsALT( TidyAttr tattr );
bool tidyAttrIsLONGDESC( TidyAttr tattr );
bool tidyAttrIsUSEMAP( TidyAttr tattr );
bool tidyAttrIsISMAP( TidyAttr tattr );
bool tidyAttrIsLANGUAGE( TidyAttr tattr );
bool tidyAttrIsTYPE( TidyAttr tattr );
bool tidyAttrIsVALUE( TidyAttr tattr );
bool tidyAttrIsCONTENT( TidyAttr tattr );
bool tidyAttrIsTITLE( TidyAttr tattr );
bool tidyAttrIsXMLNS( TidyAttr tattr );
bool tidyAttrIsDATAFLD( TidyAttr tattr );
bool tidyAttrIsWIDTH( TidyAttr tattr );
bool tidyAttrIsHEIGHT( TidyAttr tattr );
bool tidyAttrIsFOR( TidyAttr tattr );
bool tidyAttrIsSELECTED( TidyAttr tattr );
bool tidyAttrIsCHECKED( TidyAttr tattr );
bool tidyAttrIsLANG( TidyAttr tattr );
bool tidyAttrIsTARGET( TidyAttr tattr );
bool tidyAttrIsHTTP_EQUIV( TidyAttr tattr );
bool tidyAttrIsREL( TidyAttr tattr );
bool tidyAttrIsOnMOUSEMOVE( TidyAttr tattr );
bool tidyAttrIsOnMOUSEDOWN( TidyAttr tattr );
bool tidyAttrIsOnMOUSEUP( TidyAttr tattr );
bool tidyAttrIsOnCLICK( TidyAttr tattr );
bool tidyAttrIsOnMOUSEOVER( TidyAttr tattr );
bool tidyAttrIsOnMOUSEOUT( TidyAttr tattr );
bool tidyAttrIsOnKEYDOWN( TidyAttr tattr );
bool tidyAttrIsOnKEYUP( TidyAttr tattr );
bool tidyAttrIsOnKEYPRESS( TidyAttr tattr );
bool tidyAttrIsOnFOCUS( TidyAttr tattr );
bool tidyAttrIsOnBLUR( TidyAttr tattr );
bool tidyAttrIsBGCOLOR( TidyAttr tattr );
bool tidyAttrIsLINK( TidyAttr tattr );
bool tidyAttrIsALINK( TidyAttr tattr );
bool tidyAttrIsVLINK( TidyAttr tattr );
bool tidyAttrIsTEXT( TidyAttr tattr );
bool tidyAttrIsSTYLE( TidyAttr tattr );
bool tidyAttrIsABBR( TidyAttr tattr );
bool tidyAttrIsCOLSPAN( TidyAttr tattr );
bool tidyAttrIsROWSPAN( TidyAttr tattr );

/** @} End AttrIsAttributeName group */

/** @} end AttrAsk group */


/** @defgroup AttrGet Attribute Retrieval
**
** Lookup an attribute from a given node
** @{
*/

TidyAttr tidyAttrGetById( TidyNode tnod, TidyAttrId attId );

/** @defgroup AttrGetAttributeName Deprecated attribute retrieval per AttrId
**
** @deprecated The functions tidyAttrGet{AttributeName} are deprecated and 
** should be replaced by tidyAttrGetById.
** For instance, tidyAttrGetID( TidyNode tnod ) can be replaced by 
** tidyAttrGetById( TidyNode tnod, TidyAttr_ID ). This avoids a potential
** name clash with tidyAttrGetId for case-insensitive languages.
** @{
*/
TidyAttr tidyAttrGetHREF( TidyNode tnod );
TidyAttr tidyAttrGetSRC( TidyNode tnod );
TidyAttr tidyAttrGetID( TidyNode tnod );
TidyAttr tidyAttrGetNAME( TidyNode tnod );
TidyAttr tidyAttrGetSUMMARY( TidyNode tnod );
TidyAttr tidyAttrGetALT( TidyNode tnod );
TidyAttr tidyAttrGetLONGDESC( TidyNode tnod );
TidyAttr tidyAttrGetUSEMAP( TidyNode tnod );
TidyAttr tidyAttrGetISMAP( TidyNode tnod );
TidyAttr tidyAttrGetLANGUAGE( TidyNode tnod );
TidyAttr tidyAttrGetTYPE( TidyNode tnod );
TidyAttr tidyAttrGetVALUE( TidyNode tnod );
TidyAttr tidyAttrGetCONTENT( TidyNode tnod );
TidyAttr tidyAttrGetTITLE( TidyNode tnod );
TidyAttr tidyAttrGetXMLNS( TidyNode tnod );
TidyAttr tidyAttrGetDATAFLD( TidyNode tnod );
TidyAttr tidyAttrGetWIDTH( TidyNode tnod );
TidyAttr tidyAttrGetHEIGHT( TidyNode tnod );
TidyAttr tidyAttrGetFOR( TidyNode tnod );
TidyAttr tidyAttrGetSELECTED( TidyNode tnod );
TidyAttr tidyAttrGetCHECKED( TidyNode tnod );
TidyAttr tidyAttrGetLANG( TidyNode tnod );
TidyAttr tidyAttrGetTARGET( TidyNode tnod );
TidyAttr tidyAttrGetHTTP_EQUIV( TidyNode tnod );
TidyAttr tidyAttrGetREL( TidyNode tnod );
TidyAttr tidyAttrGetOnMOUSEMOVE( TidyNode tnod );
TidyAttr tidyAttrGetOnMOUSEDOWN( TidyNode tnod );
TidyAttr tidyAttrGetOnMOUSEUP( TidyNode tnod );
TidyAttr tidyAttrGetOnCLICK( TidyNode tnod );
TidyAttr tidyAttrGetOnMOUSEOVER( TidyNode tnod );
TidyAttr tidyAttrGetOnMOUSEOUT( TidyNode tnod );
TidyAttr tidyAttrGetOnKEYDOWN( TidyNode tnod );
TidyAttr tidyAttrGetOnKEYUP( TidyNode tnod );
TidyAttr tidyAttrGetOnKEYPRESS( TidyNode tnod );
TidyAttr tidyAttrGetOnFOCUS( TidyNode tnod );
TidyAttr tidyAttrGetOnBLUR( TidyNode tnod );
TidyAttr tidyAttrGetBGCOLOR( TidyNode tnod );
TidyAttr tidyAttrGetLINK( TidyNode tnod );
TidyAttr tidyAttrGetALINK( TidyNode tnod );
TidyAttr tidyAttrGetVLINK( TidyNode tnod );
TidyAttr tidyAttrGetTEXT( TidyNode tnod );
TidyAttr tidyAttrGetSTYLE( TidyNode tnod );
TidyAttr tidyAttrGetABBR( TidyNode tnod );
TidyAttr tidyAttrGetCOLSPAN( TidyNode tnod );
TidyAttr tidyAttrGetROWSPAN( TidyNode tnod );

/** @} End AttrGetAttributeName group */

/** @} end AttrGet group */

/*
 * local variables:
 * mode: c
 * indent-tabs-mode: nil
 * c-basic-offset: 4
 * eval: (c-set-offset 'substatement-open 0)
 * end:
 */
