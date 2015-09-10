## vim: filetype=python

import ctypes
import os
import sys


class AnalysisContext(object):
    # TODO: document this class and its methods

    def __init__(self, c_value=None):
        self._c_value = (_create_analysis_context()
                         if c_value is None else c_value)

    def __del__(self):
        _destroy_analysis_context(self._c_value)
        super(AnalysisContext, self).__init__()

    def get_from_file(self, filename, reparse=False):
        c_value = _get_analysis_unit_from_file(self._c_value, filename,
                                               reparse)
        if not c_value.value:
            raise IOError('Could not open {}'.format(filename))
        return AnalysisUnit(c_value)

    def get_from_buffer(self, filename, buffer):
        c_value = _get_analysis_unit_from_buffer(self._c_value, filename,
                                                 buffer, len(buffer))
        return AnalysisUnit(c_value)

    def remove(self, filename):
        if not _remove_analysis_unit(self._c_value, filename):
            raise KeyError('No such unit: {}'.format(filename))


class AnalysisUnit(object):
    # TODO: document this class and its methods

    class DiagnosticsList(object):
        def __init__(self, unit):
            self.unit = unit

        def __repr__(self):
            return 'DiagnosticsList({})'.format(repr(list(self)))

        def __len__(self):
            return _unit_diagnostic_count(self.unit._c_value)

        def __getitem__(self, key):
            if not isinstance(key, int):
                msg = 'list indices must be integers, not {}'.format(
                    type(key))
                raise TypeError(msg)

            diag = _Diagnostic()
            success = _unit_diagnostic(self.unit._c_value, key,
                                       ctypes.byref(diag))
            if not success:
                raise IndexError('diagnostic index out of range')
            else:
                result = _wrap_diagnostic(diag)
                _free_str(diag.message)
                return result

    def __init__(self, c_value):
        self._c_value = c_value
        _unit_incref(self._c_value)

    def __del__(self):
        _unit_decref(self._c_value)
        super(AnalysisUnit, self).__init__()

    def reparse(self, buffer=None):
        if buffer is None:
            if not _unit_reparse_from_file(self._c_value):
                raise IOError('Could not reparse the unit from file')
        else:
            _unit_reparse_from_buffer(self._c_value, buffer, len(buffer))

    @property
    def root(self):
        return _wrap_astnode(_unit_root(self._c_value))

    @property
    def diagnostics(self):
        return self.DiagnosticsList(self)


class Token(object):
    # TODO: document this class and its methods

    def __init__(self, c_value):
        text = _token_text(c_value)
        self.text = text.value
        _free_str(text)

    def __repr__(self):
        return "<Token {}>".format(self.text)


class Sloc(object):
    # TODO: document this class and its methods

    def __init__(self, line, column):
        self.line = line
        self.column = column

    def __nonzero__(self):
        return self.line or self.column

    def __str__(self):
        return '{}:{}'.format(self.line, self.column)

    def __repr__(self):
        return '<Sloc {} at {:#x}>'.format(self, id(self))


class SlocRange(object):
    # TODO: document this class and its methods

    def __init__(self, start, end):
        self.start = start
        self.end = end

    def __nonzero__(self):
        return self.start or self.end

    def __str__(self):
        return '{}-{}'.format(self.start, self.end)

    def __repr__(self):
        return '<SlocRange {} at {:#x}>'.format(self, id(self))


class Diagnostic(object):
    # TODO: document this class and its methods

    def __init__(self, sloc_range, message):
        self.sloc_range = sloc_range
        self.message = message

    def __str__(self):
        return '{}: {}'.format(self.sloc_range, self.message)

    def __repr__(self):
        return '<Diagnostic {} at {:#x}>'.format(repr(str(self)), id(self))


class ASTNode(object):
    # TODO: document this class and its methods

    _field_names = ()

    def __init__(self, c_value):
        self._c_value = c_value
        _node_incref(self._c_value)

    def __del__(self):
        _node_decref(self._c_value)
        super(ASTNode, self).__init__()

    @property
    def kind_name(self):
        return self._kind_name

    @property
    def sloc_range(self):
        result = _SlocRange()
        _node_sloc_range(self._c_value, ctypes.byref(result))
        return _wrap_sloc_range(result)

    def lookup(self, sloc):
        c_sloc = _unwrap_sloc(sloc)
        c_node =_lookup_in_node(self._c_value,
                                ctypes.byref(c_sloc))
        return _wrap_astnode(c_node)

    @property
    def parent(self):
        return _wrap_astnode(_node_parent(self._c_value))

    def __len__(self):
        """Return the number of ASTNode children this node has"""
        return _node_child_count(self._c_value)

    def __getitem__(self, key):
        """Return the Nth ASTNode child this node has

        Raise an IndexError if "key" is out of range.
        """
        if not isinstance(key, int):
            msg = 'ASTNode children are integer-indexed (got {})'.format(
                type(key))
            raise TypeError(msg)

        result = _node()
        success = _node_child(self._c_value, key, ctypes.byref(result))
        if not success:
            raise IndexError('child index out of range')
        else:
            return _wrap_astnode(result)

    def iter_fields(self):
        """Iterate through all the fields this node contains

        Return an iterator that yields (field_name, field_value) couples for
        all fields in this node.
        """
        for field_name in self._field_names:
            yield (field_name, getattr(self, 'f_{}'.format(field_name)))

    def dump(self, indent='', file=sys.stdout):
        """Dump the sub-tree in a human-readable format on the given file.

        :param str indent: Prefix printed on each line during the dump.
        :param file file: File in which the dump must occur.
        """

        def print_node(name, value):
            if isinstance(value, ASTNode):
                print >> file, '{}{}:'.format(indent, name)
                value.dump(indent + '  ', file)
            elif isinstance(value, Token):
                print >> file, '{}{}: Token({})'.format(indent, name,
                                                        repr(value.text))
            else:
                print >> file, '{}{}: {}'.format(indent, name, value)

        print >> file, '{}<{}>'.format(indent, self.kind_name)
        indent = indent + '|'
        if isinstance(self, ASTList):
            for i, value in enumerate(self):
                print_node("item {}".format(i), value)
        else:
            for name, value in self.iter_fields():
                print_node(name, value)


class ASTList(ASTNode):
    # TODO: document this class
    _kind_name = 'list'


% for subclass_decl in astnode_subclass_decls:
${subclass_decl}
% endfor

UNINITIALIZED = 'uninitialized'

% for chunk in _self.py_astnode_field_types.values():
${chunk}
% endfor

#
# Low-level C binding
#

so_ext = {
    'win32':  'dll',
    'darwin': 'dylib',
}.get(sys.platform, 'so')
_c_lib = ctypes.cdll.LoadLibrary(
    "lib${c_api.shared_object_basename}.{}".format(so_ext)
)


def _import_func(name, argtypes, restype):
    """
    Import "name" from the C library, set its arguments/return types and return
    the binding.
    """
    func = getattr(_c_lib, name)
    func.argtypes = argtypes
    func.restype = restype
    return func


class string_to_free(ctypes.c_char_p):
    """
    Regular c_char_p instances automatically copy the input string on struct
    field access/function return, which makes it impossible to free it
    afterwards (we have no handle to the returned buffer).  Subclassing it
    removes this automation.
    """
    pass


class _analysis_context(ctypes.c_void_p):
    pass
class _analysis_unit(ctypes.c_void_p):
    pass
class _node(ctypes.c_void_p):
    pass
_enum_node_kind = ctypes.c_uint
class _token(ctypes.c_void_p):
    pass


class _Sloc(ctypes.Structure):
    _fields_ = [("line", ctypes.c_uint32),
                ("column", ctypes.c_uint16)]


class _SlocRange(ctypes.Structure):
    _fields_ = [("start", _Sloc),
                ("end", _Sloc)]


class _Diagnostic(ctypes.Structure):
    _fields_ = [("sloc_range", _SlocRange),
                ("message", string_to_free)]


_initialize = _import_func(
    '${capi.lib_name}_initialize',
    [], None
)
_initialize()


# Analysis primitives
_create_analysis_context = _import_func(
    '${capi.get_name("create_analysis_context")}',
    [], _analysis_context
)
_destroy_analysis_context = _import_func(
    '${capi.get_name("destroy_analysis_context")}',
    [_analysis_context, ], None
)
_get_analysis_unit_from_file = _import_func(
    '${capi.get_name("get_analysis_unit_from_file")}',
    [_analysis_context, ctypes.c_char_p, ctypes.c_int], _analysis_unit
)
_get_analysis_unit_from_buffer = _import_func(
    '${capi.get_name("get_analysis_unit_from_buffer")}',
    [_analysis_context, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t],
    _analysis_unit
)
_remove_analysis_unit = _import_func(
    '${capi.get_name("remove_analysis_unit")}',
    [_analysis_context, ctypes.c_char_p], ctypes.c_int
)
_unit_root = _import_func(
    '${capi.get_name("unit_root")}',
    [_analysis_unit], _node
)
_unit_diagnostic_count = _import_func(
    '${capi.get_name("unit_diagnostic_count")}',
    [_analysis_unit], ctypes.c_uint
)
_unit_diagnostic = _import_func(
    '${capi.get_name("unit_diagnostic")}',
    [_analysis_unit, ctypes.c_uint, ctypes.POINTER(_Diagnostic)], ctypes.c_int
)
_unit_incref = _import_func(
    '${capi.get_name("unit_incref")}',
    [_analysis_unit], _analysis_unit
)
_unit_decref = _import_func(
    '${capi.get_name("unit_decref")}',
    [_analysis_unit], None
)
_unit_reparse_from_file = _import_func(
    '${capi.get_name("unit_reparse_from_file")}',
    [_analysis_unit], ctypes.c_int
)
_unit_reparse_from_buffer = _import_func(
    '${capi.get_name("unit_reparse_from_buffer")}',
    [_analysis_unit, ctypes.c_char_p, ctypes.c_size_t], None
)

_free_str = _import_func(
    '${capi.get_name("free_str")}',
    [string_to_free], None
)

# General AST node primitives
_node_kind = _import_func(
    '${capi.get_name("node_kind")}',
    [_node], _enum_node_kind
)
_kind_name = _import_func(
    '${capi.get_name("kind_name")}',
    [_enum_node_kind], string_to_free
)
_node_sloc_range = _import_func(
    '${capi.get_name("node_sloc_range")}',
    [_node, ctypes.POINTER(_SlocRange)], None
)
_lookup_in_node = _import_func(
    '${capi.get_name("lookup_in_node")}',
    [_node, ctypes.POINTER(_Sloc)], _node
)
_node_parent = _import_func(
    '${capi.get_name("node_parent")}',
    [_node], _node
)
_node_child_count = _import_func(
    '${capi.get_name("node_child_count")}',
    [_node], ctypes.c_uint
)
_node_child = _import_func(
    '${capi.get_name("node_child")}',
    [_node, ctypes.c_uint, ctypes.POINTER(_node)], ctypes.c_int
)
_node_incref = _import_func(
    '${capi.get_name("node_incref")}',
    [_node], _node
)
_node_decref = _import_func(
    '${capi.get_name("node_decref")}',
    [_node], None
)

_token_text = _import_func(
    '${capi.get_name("token_text")}',
    [_token], string_to_free
)

% for astnode in _self.astnode_types:
    % for primitive in _self.c_astnode_primitives[astnode]:
_${primitive.name.lower} = _import_func(
    '${capi.get_name(primitive.name)}',
    [_node,
     ctypes.POINTER(${primitive.field.type.py_type(pyapi).name_low})],
    ctypes.c_int
)
    % endfor
% endfor


# Extensions handling
_register_extension = _import_func(
    '${capi.get_name("register_extension")}',
    [ctypes.c_char_p], ctypes.c_uint
)
_node_extension_destructor = ctypes.CFUNCTYPE(
    ctypes.c_void_p,
    _node, ctypes.c_void_p
)
_node_extension = _import_func(
    '${capi.get_name("node_extension")}',
    [_node, ctypes.c_uint, _node_extension_destructor],
    ctypes.POINTER(ctypes.c_void_p)
)


#
# Layering helpers
#

def _wrap_sloc(c_value):
    return Sloc(c_value.line, c_value.column)

def _unwrap_sloc(sloc):
    return _Sloc(sloc.line, sloc.column)

def _wrap_sloc_range(c_value):
    return SlocRange(_wrap_sloc(c_value.start),
                     _wrap_sloc(c_value.end))

def _wrap_diagnostic(c_value):
    return Diagnostic(_wrap_sloc_range(c_value.sloc_range),
                      c_value.message.value)


_kind_to_astnode_cls = {
    1: ASTList,
    % for subclass in _self.astnode_types:
        % if not subclass.abstract:
    ${_self.node_kind_constants[subclass]}: ${subclass.name()},
        % endif
    % endfor
}

# We use the extension mechanism to keep a single wrapper ASTNode instance per
# underlying AST node. This way, users can store attributes in wrappers and
# expect to find these attributes back when getting the same node later.

# TODO: this mechanism currently introduces reference loops between the ASTNode
# and its wrapper. When a Python wraper is created for some ASTNode, both will
# never be deallocated (i.e. we have memory leaks). This absolutely needs to be
# fixed for real world use but in the meantime, let's keep this implementation
# for prototyping.

_node_extension_id = _register_extension("python_api_astnode_wrapper")
def _node_ext_dtor_py(c_node, c_pyobj):
    """
    Callback for extension upon ASTNode destruction: free the reference for the
    Python wrapper.
    """
    # At this point, c_pyobj is a System.Address in Ada that have been decoded
    # by ctypes.c_void_p as a "long" Python object. We used to try to convert
    # it into a ctypes.py_object with:
    #   ctypes.py_object(c_pyobj)
    # but this was wrong: the result was a reference to the long object itself,
    # not to the object whose address was stored in the long. And this led to
    # random memory issues with the call to Py_DecRef... Actual casting is the
    # way to go.
    c_pyobj = ctypes.cast(c_pyobj, ctypes.py_object)
    ctypes.pythonapi.Py_DecRef(c_pyobj)

_node_ext_dtor_c = _node_extension_destructor(_node_ext_dtor_py)

def _wrap_astnode(c_value):
    if not c_value:
        return None

    # First, look if we already built a wrapper for this node so that we only
    # have one wrapper per node.
    c_pyobj_p = _node_extension(c_value, _node_extension_id, _node_ext_dtor_c)
    c_pyobj_p = ctypes.cast(
        c_pyobj_p,
        ctypes.POINTER(ctypes.py_object)
    )
    if c_pyobj_p.contents:
        return c_pyobj_p.contents.value
    else:
        # Create a new wrapper for this node...
        kind = _node_kind(c_value)
        py_obj = _kind_to_astnode_cls[kind](c_value)

        # .. and store it in our extension.
        c_pyobj_p[0] = ctypes.py_object(py_obj)

        # We want to increment its ref count so that the wrapper will be alive
        # as long as the extension references it.
        ctypes.pythonapi.Py_IncRef(ctypes.py_object(py_obj))

        return py_obj
