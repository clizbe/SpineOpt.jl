#############################################################################
# Copyright (C) 2017 - 2021  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
"""
	add_model_algorithm(db_url)

Add `model_algorithm`.
"""
function add_model_algorithm(db_url, log_level)
	@log log_level 0 "Converting `model_type.spineopt_mga` to `model_algorithm.mga_algorithm`"
	data = run_request(
		db_url,
		"query",
		("list_value_sq", "parameter_value_list_sq", "object_parameter_value_sq", "parameter_definition_sq"),
	)
	spineopt_mga_pvals = [
		x
		for x in data["object_parameter_value_sq"]
		if x["parameter_name"] == "model_type"
		&& parse_db_value(x["value"], nothing) == "spineopt_mga"
	]
	if !isempty(spineopt_mga_pvals)
		import_data(db_url, ""; object_parameters=[("model", "model_algorithm")])
		model_algo_ids = [
			x["id"]
			for x in run_request(db_url, "query", ("parameter_definition_sq",))["parameter_definition_sq"]
			if x["name"] == "model_algorithm"
		]
		model_algo_id = only(model_algo_ids)
		to_upd = [
			Dict("id" => x["id"], "value" => unparse_db_value("spineopt_standard")[1]) for x in spineopt_mga_pvals
		]
		to_add = [
			Dict(
				"entity_class_id" => x["entity_class_id"],
				"entity_id" => x["entity_id"],
				"parameter_definition_id" => model_algo_id,
				"alternative_id" => x["alternative_id"],
				"value" => unparse_db_value("mga_algorithm")[1],
				"type" => nothing,
			)
			for x in spineopt_mga_pvals
		]
		run_request(db_url, "call_method", ("update_parameter_values", to_upd...))
		run_request(db_url, "call_method", ("add_parameter_values", to_add...))
	end
	model_type_list_ids = [x["id"] for x in data["parameter_value_list_sq"] if x["name"] == "model_type_list"]
	length(model_type_list_ids) == 1 || return true
	model_type_list_id = only(model_type_list_ids)
	mga_ids = [
		x["id"]
		for x in data["list_value_sq"]
		if x["parameter_value_list_id"] == model_type_list_id
		&& parse_db_value(x["value"], nothing) == "spineopt_mga"
	]
	length(mga_ids) == 1 || return true
	mga_id = only(mga_ids)
	run_request(db_url, "call_method", ("cascade_remove_items",), Dict(:list_value => [mga_id]))
	true
end
