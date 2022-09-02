function [flags,keyvals,varargout]  = SOFAarghelper(posdepnames,definput,arglist,callfun)
%SOFAarghelper - Parse arguments for SOFA
%   Usage: [flags,keyvals,varargout]  = SOFAarghelper(posdepnames, definput, arglist, callfun);
%
%   Input parameters:
%      posdepnames : Names of the position dependant parameters.
%      definput    : Struct to define the allowed input.
%      arglist     : Commandline of the calling function (varargin).
%      callfun     : Name of calling function (optional).
%
%   Output parameters:
%      flags       : Struct with information about flags.
%      keyvals     : Struct with key / values.
%      varargout   : The position dependant pars. properly initialized.
%
%   [flags,keyvals,varargout]=SOFAarghelper(posdepnames,definput,arglist,callfun) assists in
%   parsing input parameters for a function. Parameters come in
%   four categories:
%  
%      Position dependant parameters. These must not be strings. These are
%       the first parameters passed to a function, and they are really just a short way
%       of specifying key/value pairs. See below.
%
%      Flags. These are single string appearing after the position-dependent
%       parameters.
%
%      Key/value pairs. The key is always a string followed by the value, which can be
%       anything.
%
%      Expansions. These appear as flags, that expand into a pre-defined list of parameters.
%       This is a short-hand way of specifying standard sets of flags and key/value pairs.
%
%   The parameters are parsed in order, so parameters appearing later in varargin will override
%   previously set values.
%
%   The following example for calling SOFAARGHELPER is taken from SOFAupdateDimensions:
% 
%       definput.keyvals.Index=[];
%       definput.keyvals.verbose=0;
%       definput.flags.type={'data','nodata'};
%       [flags,kv]=SOFAarghelper({'Index'},definput,varargin);
% 
%   The first line defines a key/value pair with the key 'Index' having an initial value of `[]` (the empty matrix).
% 
%   The second line defines a key/value pair with the key 'verbose' having an initial value of `0`.
% 
%   The third line defines a group of flags by the name of type. The
%   group type contains the flags `data` and `nodata`, which can
%   both be specified on the command line by the user. The group-name
%   type is just for internal use, and does not appear to the user. The
%   flag mentioned first in the list will be selected by default, and only
%   one flag in a group can be selected at any time. A group can contain as
%   many flags as desired.
%  
%   The fourth line is the actual call to SOFAARGHELPER which defines the
%   output flags and `kv`.  The input `{'Index'}` indicates that the value of
%   the parameter 'Index' can also be given as the very first value in
%   varargin.
%
%   The output struct kv contains the key/value pairs, so the value associated to 'Index' is
%   stored in kv.Index.
%
%   The output struct flags contains information about the flags choosen
%   by the user. The value of flags.type will be set to the selected flag
%   in the group type and additionally, the value of `flags.do_data`
%   will be 1 if 'data' was selected and 0 otherwise, and similarly for
%   'nodata'. This allows for easy checking of selected flags.

% #Author: Peter L. Soendergaard, Copyright (C) 2005-2012
% #Author: Piotr Majdak: Modified from the LTFAT 1.1.2 for SOFA by Piotr Majdak.
% #Author: Michael Mihocic: header documentation updated (20.10.2021)
% #Author: Michael Mihocic: license changed from GPL to EUPL, in agreement with Peter L. Soendergaard (31.08.2022)
% #Author: Michael Mihocic: header documentation/example updated to SOFAupdateDimensions (02.09.2022)
%
% SOFA Toolbox - function SOFAarghelper
% Copyright (C) Acoustics Research Institute - Austrian Academy of Sciences
% Licensed under the EUPL, Version 1.2 or - as soon they will be approved by the European Commission - subsequent versions of the EUPL (the "License")
% You may not use this work except in compliance with the License.
% You may obtain a copy of the License at: https://joinup.ec.europa.eu/software/page/eupl
% Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing  permissions and limitations under the License.

persistent SOFA_CONF;

if isempty(SOFA_CONF)
  SOFA_CONF.fundefs = struct;
end;

if ischar(posdepnames)
  % Special interface needed for ltfatsetdefaults and ltfatgetdefaults,
  % activated when first argument is a string.

  % First input  argument, posdepnames, is a string, one of the options
  % in the "switch" section below
  % Second input argument, definput,    is a function name to get or set
  % Third  input argument, arglist ,    is a cell-array with options to set.
  
  switch(lower(posdepnames))
   case 'get'
    if isfield(SOFA_CONF.fundefs,definput)
      flags=SOFA_CONF.fundefs.(definput);
    else
      flags={};
    end;
   case 'set'
    SOFA_CONF.fundefs.(definput)=arglist;
   case 'all'
    flags=SOFA_CONF.fundefs;
   case 'clearall'
    SOFA_CONF.fundefs=struct; 
  end;
  return
end;

if nargin<4
  f=dbstack;  
  callfun=f(2).name;
end;

nposdep=numel(posdepnames);

% Resolve import specifications BEFORE adding our own specifications.
if isfield(definput,'import')
  for imp = definput.import;
    definput=feval(['arg_',imp{1}],definput);
  end;
end;

if isfield(definput,'flags')
  defflags=definput.flags;
else
  defflags=struct;
end;

if isfield(definput,'keyvals')
  defkeyvals=definput.keyvals;
else
  defkeyvals=struct;
end;

if isfield(definput,'groups')
  groups=definput.groups;
else
  groups=struct;
end;

total_args = numel(arglist);

% Determine the position of the first optional argument.
% If no optional argument is given, return nposdep+1
first_str_pos = 1;
while first_str_pos<=total_args && ~ischar(arglist{first_str_pos}) 
  first_str_pos = first_str_pos +1;    
end;

% If more than nposdep arguments are given, the first additional one must
% be a string
if (first_str_pos>nposdep+1)
  error('%s: Too many input arguments',upper(callfun));
end;

n_first_args=min(nposdep,first_str_pos-1);

keyvals=defkeyvals;      

% Copy the given first arguments
for ii=1:n_first_args
  keyvals.(posdepnames{ii})=arglist{ii};
end;

% Initialize the position independent parameters.
% and create reverse mapping of flag -> group
flagnames=fieldnames(defflags);
flags=struct;
% In order for flags to start with a number, it is necessary to add
% 'x_' before the flag when the flags are used a field names in
% flagreverse. Externally, flags are never used a field names in
% structs, so this is an internal problem in ltfatarghelper that is
% fixed this way.
flagsreverse=struct;
for ii=1:numel(flagnames)
  name=flagnames{ii};
  flaggroup=defflags.(name);
  flags.(name)=flaggroup{1};
  for jj=1:numel(flaggroup)
    flagsreverse.(['x_', flaggroup{jj}])=name;
    flags.(['do_',flaggroup{jj}])=0;
  end;
  flags.(['do_',flaggroup{1}])=1;
end;

%Get the rest of the arguments
restlist = arglist(first_str_pos:end);

%Check for default arguments
if isfield(SOFA_CONF.fundefs,callfun)
  s=SOFA_CONF.fundefs.(callfun);
  restlist=[s,restlist];
end;

% Check for import defaults
if isfield(definput,'importdefaults')
  % Add the importdefaults before the user specified arguments.
  restlist=[definput.importdefaults,restlist];
end;

while ~isempty(restlist)
  argname=restlist{1};
  restlist=restlist(2:end);  % pop
  found=0;
  
  % Is this name a flag? If so, set it
  if isfield(flagsreverse,['x_',argname])
    % Unset all other flags in this group
    flaggroup=defflags.(flagsreverse.(['x_',argname]));
    for jj=1:numel(flaggroup)
      flags.(['do_',flaggroup{jj}])=0;
    end;
    
    flags.(flagsreverse.(['x_',argname]))=argname;
    flags.(['do_',argname])=1;
    found=1;
  end;
  
  % Is this name the key of a key/value pair? If so, set the value.
  if isfield(defkeyvals,argname)      
    keyvals.(argname)=restlist{1};
    restlist=restlist(2:end);
    found=1;
  end;
  
  % Is this name a group definition? If so, put the group in front of the parameters
  if isfield(groups,argname)
    s=groups.(argname);
    restlist=[s,restlist];
    found=1;
  end;
  
  % Is the name == 'argimport'
  if strcmp('argimport',argname)   
    fieldnames_flags= fieldnames(restlist{1});  
    fieldnames_kvs  = fieldnames(restlist{2});        
    for ii=1:numel(fieldnames_flags)
      importname=fieldnames_flags{ii};
      flags.(importname)=restlist{1}.(importname);
    end;
    for ii=1:numel(fieldnames_kvs)
      importname=fieldnames_kvs{ii};
      keyvals.(importname)=restlist{2}.(importname);
    end;      
    restlist=restlist(3:end);
    found=1;
  end;
  
  if found==0
    if ischar(argname)
      error('%s: Unknown parameter: %s',upper(callfun),argname);
    else
      error('%s: Parameter is not a string, it is of class %s',upper(callfun),class(argname));          
    end;      
  end;
  
  %ii=ii+1;
end;

% Fill varargout

varargout=cell(1,nposdep);
for ii=1:nposdep
    varargout(ii)={keyvals.(posdepnames{ii})};
end;

