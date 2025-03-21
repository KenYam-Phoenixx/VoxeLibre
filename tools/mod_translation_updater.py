#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Script to generate Luanti translation template files and update
# translation files.
#
# Copyright (C) 2019 Joachim Stolberg, 2020 FaceDeer, 2020 Louis Royer,
#                    2023 Wuzzy.
# License: LGPLv2.1 or later (see LICENSE file for details)

import os, fnmatch, re, shutil, errno
from sys import argv as _argv
from sys import stderr as _stderr
from collections import defaultdict

# Optional jellyfish for fuzzy matching
has_jellyfish = False
try:
	import jellyfish
	has_jellyfish = True
except: pass

# Running params
params = {"recursive": False,
	"help": False,
	"verbose": False,
	"folders": [],
	"old-file": False,
	"break-long-lines": False,
	"print-source": False,
	"truncate-unused": False,
	"dofile-order": False,
	"jellyfish": False,
}
# Available CLI options
options = {"recursive": ['--recursive', '-r'],
	"help": ['--help', '-h'],
	"verbose": ['--verbose', '-v'],
	"old-file": ['--old-file', '-o'],
	"break-long-lines": ['--break-long-lines', '-b'],
	"print-source": ['--print-source', '-p'],
	"truncate-unused": ['--truncate-unused', '-t'],
	"dofile-order": ['--dofile-order', '-d'],
	"jellyfish": ['--jellyfish', '-j'],
}

# Strings longer than this will have extra space added between
# them in the translation files to make it easier to distinguish their
# beginnings and endings at a glance
doublespace_threshold = 80

# These symbols mark comment lines showing the source file name.
# A comment may look like "##[ init.lua ]##".
symbol_source_prefix = "##[ "
symbol_source_suffix = " ]##"

# comment to mark the section of old/unused strings
comment_unused = "##### not used anymore #####"

def set_params_folders(tab: list):
	'''Initialize params["folders"] from CLI arguments.'''
	# Discarding argument 0 (tool name)
	for param in tab[1:]:
		stop_param = False
		for option in options:
			if param in options[option]:
				stop_param = True
				break
		if not stop_param:
			params["folders"].append(os.path.abspath(param))

def set_params(tab: list):
	'''Initialize params from CLI arguments.'''
	for option in options:
		for option_name in options[option]:
			if option_name in tab:
				params[option] = True
				break

def print_help(name):
	'''Prints some help message.'''
	print(f'''SYNOPSIS
	{name} [OPTIONS] [PATHS...]
DESCRIPTION
	{', '.join(options["help"])}
		prints this help message
	{', '.join(options["recursive"])}
		run on all subfolders of paths given
	{', '.join(options["old-file"])}
		create *.old files
	{', '.join(options["break-long-lines"])}
		add extra line breaks before and after long strings
	{', '.join(options["print-source"])}
		add comments denoting the source file
	{', '.join(options["verbose"])}
		add output information
	{', '.join(options["truncate-unused"])}
		delete unused strings from files
	{', '.join(options["dofile-order"])}
		try to order files by their order from init.lua (not recursive)
	{', '.join(options["jellyfish"])}
		use jellyfish library for fuzzy matching
''')

def main():
	'''Main function'''
	set_params(_argv)
	set_params_folders(_argv)
	if params["help"]:
		print_help(_argv[0])
	else:
		# Add recursivity message
		print("Running ", end='')
		if params["recursive"]:
			print("recursively ", end='')
		# Running
		if len(params["folders"]) >= 2:
			print("on folder list:", params["folders"])
			for f in params["folders"]:
				if params["recursive"]:
					run_all_subfolders(f)
				else:
					update_folder(f)
		elif len(params["folders"]) == 1:
			print("on folder", params["folders"][0])
			if params["recursive"]:
				run_all_subfolders(params["folders"][0])
			else:
				update_folder(params["folders"][0])
		else:
			print("on folder", os.path.abspath("./"))
			if params["recursive"]:
				run_all_subfolders(os.path.abspath("./"))
			else:
				update_folder(os.path.abspath("./"))

# Compile pattern for matching lua function call
def compile_func_call_pattern(argument_pattern):
	return re.compile(
		# Look for beginning of file or anything that isn't a function identifier
		r'(?:^|[\.=,{\(\s])' +
		# Matches S, FS, NS, or NFS function call
		r'(?:S|FS|NS|NFS|N)\s*' +
		# The pattern to match argument
		argument_pattern,
		re.DOTALL)

# Add parentheses around a pattern
def parenthesize_pattern(pattern):
	return (
		# Start of argument: open parentheses and space (optional)
		r'\(\s*' +
		# The pattern to be parenthesized
		pattern +
		# End of argument or function call: space, comma, or close parentheses
		r'[\s,\)]')

# Quoted string
# Group 2 will be the string, group 1 and group 3 will be the delimiters (" or ')
# See https://stackoverflow.com/questions/46967465/regex-match-text-in-either-single-or-double-quote
pattern_lua_quoted_string = r'(["\'])((?:\\\1|(?:(?!\1)).)*)(\1)'

# Double square bracket string (multiline)
pattern_lua_square_bracket_string = r'\[\[(.*?)\]\]'

# Handles the " ... " or ' ... ' string delimiters
pattern_lua_quoted = compile_func_call_pattern(parenthesize_pattern(pattern_lua_quoted_string))

# Handles the [[ ... ]] string delimiters
pattern_lua_bracketed = compile_func_call_pattern(parenthesize_pattern(pattern_lua_square_bracket_string))

# Handles like pattern_lua_quoted, but for single parameter (without parentheses)
# See https://www.lua.org/pil/5.html for informations about single argument call
pattern_lua_quoted_single = compile_func_call_pattern(pattern_lua_quoted_string)

# Same as pattern_lua_quoted_single, but for [[ ... ]] string delimiters
pattern_lua_bracketed_single = compile_func_call_pattern(pattern_lua_square_bracket_string)

# Handles "concatenation" .. " of strings"
pattern_concat = re.compile(r'["\'][\s]*\.\.[\s]*["\']', re.DOTALL)

# Handles a translation line in *.tr file.
# Group 1 is the source string left of the equals sign.
# Group 2 is the translated string, right of the equals sign.
pattern_tr = re.compile(
	r'(.*)' # Source string
	# the separating equals sign, if NOT preceded by @, unless
	# that @ is preceded by another @
	r'(?:(?<!(?<!@)@)=)'
	r'(.*)' # Translation string
	)
pattern_name = re.compile(r'^name[ ]*=[ ]*([^ \n]*)')
pattern_tr_filename = re.compile(r'\.tr$')

# Matches bad use of @ signs in Lua string
pattern_bad_luastring = re.compile(
	r'^@$|'	# single @, OR
	r'[^@]@$|' # trailing unescaped @, OR
	r'(?<!@)@(?=[^@1-9n])' # an @ that is not escaped or part of a placeholder
)

pattern_dofile = re.compile(
	r'^\s*' # linestart and optional space
	r'(?:--\s*)?' # optional comment
	r'dofile\(' # command
	r'(?:.*?\.\. *)?' # optional expression for path names, ignored - we only support the modpath
	r'([\"\'])' # quote
	r'/' # slash (not included in pattern
	r'(?P<filename>[^\"\']+\.lua)' # filename
	r'\1' # matching closing quote
	r'\)\s*(?:--.*)?$' # end of line, optional comment
	, re.M # multiline flag: ^ and $ are line ends not string ends
)

# Attempt to read the mod's name from the mod.conf file or folder name. Returns None on failure
def get_modname(folder):
	try:
		with open(os.path.join(folder, "mod.conf"), "r", encoding='utf-8') as mod_conf:
			for line in mod_conf:
				match = pattern_name.match(line)
				if match:
					return match.group(1)
	except FileNotFoundError:
		folder_name = os.path.basename(folder)
		# Special case when run in Luanti's builtin directory
		return "__builtin" if folder_name == "builtin" else folder_name

# If there are already .tr files in /locale, returns a list of their names
def get_existing_tr_files(folder):
	out = []
	for root, dirs, files in os.walk(os.path.join(folder, 'locale/')):
		for name in files:
			if pattern_tr_filename.search(name):
				out.append(name)
	return out

def fuzzy_match(s, candidates):
	import math
	if not has_jellyfish: raise "The jellyfish library is not installed."
	if len(candidates) == 0 or len(s) < 5: return None
	scores = sorted((jellyfish.damerau_levenshtein_distance(s, c) / max(len(s), len(c)), c) for c in candidates)
	thresh = 0.2 if len(s) >= 16 else 0.8 / math.sqrt(len(s))
	if scores[0][0] > thresh: return None
	if len(scores) > 1 and scores[1][0] <= thresh:
		print("Ambiguous fuzzy match:", s, "<=>", scores[0][1], "<=>", scores[1][1])
		return None # ambiguous
	return scores[0][1]

# Converts the template dictionary to a text to be written as a file
# dGroupedKeyStrings is a dictionary of source file sets to localized strings
# dOld is a dictionary of existing translations and comments from
# the previous version of this text
def strings_to_text(dGroupedKeyStrings, dOld, mod_name, header_comments, textdomain, templ = None):
	# if textdomain is specified, insert it at the top
	if textdomain != None:
		lOut = [textdomain] # argument is full textdomain line
	# otherwise, use mod name as textdomain automatically
	else:
		lOut = [f"# textdomain: {mod_name}"]
	if templ is not None and templ[2] and (header_comments is None or not header_comments.startswith(templ[2])):
		# header comments in the template file
		lOut.append(templ[2])
	if header_comments is not None:
		lOut.append(header_comments)

	dOldStrings = set(dOld.keys())
	usedFuzzy = set()

	for source, localizedStrings in dGroupedKeyStrings.items():
		if params["print-source"] and len(source) > 0:
			lOut.append(symbol_source_prefix + " ".join(x.replace("r\\","/") for x in source) + symbol_source_suffix)
		for localizedString in localizedStrings:
			val = dOld.get(localizedString, {})
			translation = val.get("translation", "")
			comment = val.get("comment")
			templ_comment = None
			if templ:
				templ_val = templ[0].get(localizedString, {})
				templ_comment = templ_val.get("comment")

			# fuzzy matching:
			if translation == "" and params["jellyfish"] and localizedString not in dOldStrings:
				cand = fuzzy_match(localizedString, dOldStrings)
				if cand and cand in dOld:
					val = dOld.get(cand)
					translation = val.get("translation", "")
					if translation != "":
						usedFuzzy.add(cand)
						comment = val.get("comment")
						if not comment or comment == "":
							comment = "##TODO: fuzzy matched - verify and remove the comment"
						else:
							comment = comment + " ##TODO: fuzzy matched - verify and remove the comment"

			if params["break-long-lines"] and len(localizedString) > doublespace_threshold and not lOut[-1] == "":
				lOut.append("")
			if templ_comment != None and templ_comment != "" and (comment is None or comment == "" or not comment.startswith(templ_comment)):
				lOut.append(templ_comment)
			if comment != None and comment != "" and not comment.startswith("# textdomain:"):
				lOut.append(comment)
			lOut.append(f"{localizedString}={translation}")
			if params["break-long-lines"] and len(localizedString) > doublespace_threshold:
				lOut.append("")

	# all strings, to report unused strings
	dkeyStrings = set(x for y in dGroupedKeyStrings.values() for x in y)

	unusedExist = False
	if not params["truncate-unused"]:
		for key in dOld:
			if key not in dkeyStrings and not key in usedFuzzy:
				val = dOld[key]
				translation = val.get("translation")
				comment = val.get("comment")
				# only keep an unused translation if there was translated
				# text or a comment associated with it
				if translation != None and (translation != "" or comment):
					if not unusedExist:
						unusedExist = True
						lOut.append("\n\n" + comment_unused + "\n")
					if params["break-long-lines"] and len(key) > doublespace_threshold and not lOut[-1] == "":
						lOut.append("")
					if comment != None:
						lOut.append(comment)
					lOut.append(f"{key}={translation}")
					if params["break-long-lines"] and len(key) > doublespace_threshold:
						lOut.append("")
	return "\n".join(lOut) + '\n'

# Gets all translatable strings from a lua file
def read_lua_file_strings(lua_file):
	lOut = []
	with open(lua_file, encoding='utf-8') as text_file:
		text = text_file.read()

		strings = []

		for s in pattern_lua_quoted_single.findall(text):
			strings.append(s[1])
		for s in pattern_lua_bracketed_single.findall(text):
			strings.append(s)

		# Only concatenate strings after matching
		# single parameter call (without parantheses)
		text = re.sub(pattern_concat, "", text)

		for s in pattern_lua_quoted.findall(text):
			strings.append(s[1])
		for s in pattern_lua_bracketed.findall(text):
			strings.append(s)

		for s in strings:
			found_bad = pattern_bad_luastring.search(s)
			if found_bad:
				print("SYNTAX ERROR: Unescaped '@' in Lua string: " + s)
				continue
			s = s.replace('\\"', '"')
			s = s.replace("\\'", "'")
			s = s.replace("\n", "@n")
			s = s.replace("\\n", "@n")
			s = s.replace("=", "@=")
			lOut.append(s)
	return lOut

# Gets strings from an existing translation file
# returns both a dictionary of translations
# and the full original source text so that the new text
# can be compared to it for changes.
# Returns also header comments in the third return value.
def import_tr_file(tr_file):
	dOut = {}
	text = None
	in_header = True
	header_comments = None
	textdomain = None
	if os.path.exists(tr_file):
		with open(tr_file, "r", encoding='utf-8') as existing_file :
			# save the full text to allow for comparison
			# of the old version with the new output
			text = existing_file.read()
			existing_file.seek(0)
			# a running record of the current comment block
			# we're inside, to allow preceeding multi-line comments
			# to be retained for a translation line
			latest_comment_block = None
			for line in existing_file.readlines():
				line = line.rstrip('\n')
				# "##### not used anymore #####" comment
				if line == comment_unused:
					# Always delete the 'not used anymore' comment.
					# It will be re-added to the file if neccessary.
					latest_comment_block = None
					if header_comments != None:
						in_header = False
					continue
				# Comment lines
				elif line.startswith("#"):
					# Source file comments: ##[ file.lua ]##
					if line.startswith(symbol_source_prefix) and line.endswith(symbol_source_suffix):
						# This line marks the end of header comments.
						if params["print-source"]:
							in_header = False
						# Remove those comments; they may be added back automatically.
						continue

					# Store first occurance of textdomain
					# discard all subsequent textdomain lines
					if line.startswith("# textdomain:"):
						if textdomain == None:
							textdomain = line
						continue
					elif in_header:
						# Save header comments (normal comments at top of file)
						if not header_comments:
							header_comments = line
						else:
							header_comments = header_comments + "\n" + line
					else:
						# Save normal comments
						if line.startswith("# textdomain:") and textdomain == None:
							textdomain = line
						elif not latest_comment_block:
							latest_comment_block = line
						else:
							latest_comment_block = latest_comment_block + "\n" + line

					continue

				match = pattern_tr.match(line)
				if match:
					# this line is a translated line
					outval = {}
					outval["translation"] = match.group(2)
					if latest_comment_block:
						# if there was a comment, record that.
						outval["comment"] = latest_comment_block
					latest_comment_block = None
					in_header = False

					dOut[match.group(1)] = outval
	return (dOut, text, header_comments, textdomain)

# Get the order of filenames included as "dofile"
# This is very rough, but "good enough" for now
def read_lua_dofile_order(lua_file):
	with open(lua_file, encoding='utf-8') as text_file:
		for s in pattern_dofile.finditer(text_file.read()):
			yield s.group("filename")

# Walks all lua files in the mod folder, collects translatable strings,
# and writes it to a template.txt file
# Returns a dictionary of localized strings to source file lists
# that can be used with the strings_to_text function.
def generate_template(folder, mod_name):
	dOut = defaultdict(set)
	dofile_order = []
	for root, _, files in sorted(list(os.walk(folder))):
		for filename in sorted(files, key=str.lower):
			if not fnmatch.fnmatch(filename, "*.lua"): continue
			fullpath_filename = os.path.join(root, filename)

			found = read_lua_file_strings(fullpath_filename)
			if params["verbose"]:
				print(f"{fullpath_filename}: {str(len(found))} translatable strings")

			for s in found:
				dOut[s].add(os.path.relpath(fullpath_filename, start=folder))

			# Note the import sequence in init.lua only:
			if params["dofile-order"] and root == folder and filename == "init.lua":
				if len(dofile_order) == 0: dofile_order.append("init.lua")
				dofile_order.extend(read_lua_dofile_order(fullpath_filename))

	if len(dOut) == 0:
		return (None, None)

	# group strings by source occurence
	groupedStrings = defaultdict(list)
	for d, sources in dOut.items():
		sources = sorted(list(sources), key=str.lower)
		if len(dofile_order) > 0 and len(sources) > 1:
			# first use the known sources in the given order; then the remainder sorted
			sources = [x for x in dofile_order if x in sources] + [x for x in sources if not x in dofile_order]
		sources = (sources[0],) # we only care about the first occurence now
		if len(sources) == 1 and sources[0] == "init.lua": sources = tuple() # omit init.lua
		groupedStrings[sources].append(d)

	# honor "dofile" order (we use that python 3.6+ dicts are insertion-ordered)
	if params["dofile-order"] and len(groupedStrings) > 1:
		# this is not very efficient, but it really does not matter
		# first init.lua, then in dofile order, then rest alphabetically
		temp = [(tuple(), groupedStrings[()])]
		temp.extend((s,v) for x in dofile_order for s,v in groupedStrings.items() if len(s) > 0 and s[0] == x)
		temp.extend(sorted((s,v) for s,v in groupedStrings.items() if len(s) > 0 and not s[0] in dofile_order))
		groupedStrings = dict(temp)

	templ_file = os.path.join(folder, "locale/template.txt")
	if not os.path.exists(os.path.dirname(templ_file)): os.makedirs(os.path.dirname(templ_file))

	# read existing template file to preserve comments
	existing_template = import_tr_file(templ_file)
	text = strings_to_text(groupedStrings, existing_template[0], mod_name, existing_template[2], existing_template[3])
	with open(templ_file, "wt", encoding='utf-8') as template_file:
		template_file.write(text)

	new_template = import_tr_file(templ_file) # re-import to get all new data
	return (groupedStrings, new_template)

# Updates an existing .tr file, copying the old one to a ".old" file
# if any changes have happened
# dNew is the data used to generate the template, it has all the
# currently-existing localized strings
def update_tr_file(dNew, templ, mod_name, tr_file):
	if params["verbose"]:
		print(f"updating {tr_file}")

	tr_import = import_tr_file(tr_file)
	dOld = tr_import[0]
	textOld = tr_import[1]

	textNew = strings_to_text(dNew, dOld, mod_name, tr_import[2], tr_import[3], templ)

	if textOld and textOld != textNew:
		print(f"{tr_file} has changed.")
		if params["old-file"]:
			shutil.copyfile(tr_file, f"{tr_file}.old")

	with open(tr_file, "w", encoding='utf-8') as new_tr_file:
		new_tr_file.write(textNew)

# Updates translation files for the mod in the given folder
def update_mod(folder):
	if not os.path.exists(os.path.join(folder, "init.lua")):
		print(f"Mod folder {folder} is missing init.lua, aborting.")
		exit(1)
	assert not is_modpack(folder)
	modname = get_modname(folder)
	print(f"Updating translations for {modname}")
	(data, templ) = generate_template(folder, modname)
	if data == None:
		print(f"No translatable strings found in {modname}")
	else:
		for tr_file in get_existing_tr_files(folder):
			update_tr_file(data, templ, modname, os.path.join(folder, "locale/", tr_file))

def is_modpack(folder):
	return os.path.exists(os.path.join(folder, "modpack.txt")) or os.path.exists(os.path.join(folder, "modpack.conf"))

def is_game(folder):
	return os.path.exists(os.path.join(folder, "game.conf")) and os.path.exists(os.path.join(folder, "mods"))

# Determines if the folder being pointed to is a game, mod or a mod pack
# and then runs update_mod accordingly
def update_folder(folder):
	if is_game(folder):
		run_all_subfolders(os.path.join(folder, "mods"))
	elif is_modpack(folder):
		run_all_subfolders(folder)
	else:
		update_mod(folder)
	print("Done.")

def run_all_subfolders(folder):
	for modfolder in [f.path for f in os.scandir(folder) if f.is_dir() and not f.name.startswith('.')]:
		update_folder(modfolder)

main()
