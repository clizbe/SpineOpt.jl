#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
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

_is_time_slice_equal(a, b) = (start(a), end_(a)) == (start(b), end_(b))

function _is_time_slice_set_equal(ts_a, ts_b)
    length(ts_a) == length(ts_b) && all(_is_time_slice_equal(a, b) for (a, b) in zip(sort(ts_a), sort(ts_b)))
end

@testset "temporal structure" begin
    url_in = "sqlite:///$(@__DIR__)/test.sqlite"
    test_data = Dict(
        :objects => [
            ["model", "instance"], 
            ["node", "only_node"],
            ["temporal_block", "block_a"],
            ["temporal_block", "block_b"],
        ],
        :relationships => [
            ["node__temporal_block", ["only_node", "block_a"]],
            ["node__temporal_block", ["only_node", "block_b"]],
        ],
        :object_parameter_values => [
            ["model", "instance", "model_start", Dict("type" => "date_time", "data" => "2000-01-01T00:00:00")],
        ]
    )
    @testset "zero_resolution" begin
        _load_template(url_in)
        db_api.import_data_to_url(url_in; test_data...)
        object_parameter_values = [
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2000-01-02T00:00:00")],
            ["temporal_block", "block_a", "resolution", 0]
        ]
        db_api.import_data_to_url(
            url_in; 
            object_parameter_values=object_parameter_values
        )
        using_spinedb(url_in, SpineOpt)
        err_msg = "`resolution` of temporal block `block_a` cannot be zero!"
        @test_throws ErrorException(err_msg) SpineOpt.generate_temporal_structure()
    end
    @testset "block_start" begin
        _load_template(url_in)
        db_api.import_data_to_url(url_in; test_data...)
        objects = [["temporal_block", "block_c"]]
        relationships = [["node__temporal_block", ["only_node", "block_c"]]]
        object_parameter_values = [
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2000-01-03T00:00:00")],
            ["temporal_block", "block_a", "resolution", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_b", "resolution", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_c", "resolution", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_a", "block_start", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_b", "block_start", Dict("type" => "date_time", "data" => "2000-01-01T15:36:00")],
            ["temporal_block", "block_c", "block_start", nothing],
        ]
        db_api.import_data_to_url(
            url_in; 
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values
        )
        using_spinedb(url_in, SpineOpt)
        SpineOpt.generate_temporal_structure()
        @test start(first(time_slice(temporal_block=temporal_block(:block_a)))) == DateTime("2000-01-02T00:00:00")
        @test start(first(time_slice(temporal_block=temporal_block(:block_b)))) == DateTime("2000-01-01T15:36:00")
        @test start(first(time_slice(temporal_block=temporal_block(:block_c)))) == DateTime("2000-01-01T00:00:00")
    end
    @testset "block_end" begin
        _load_template(url_in)
        db_api.import_data_to_url(url_in; test_data...)
        objects = [["temporal_block", "block_c"]]
        relationships = [["node__temporal_block", ["only_node", "block_c"]]]
        object_parameter_values = [
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2000-01-03T00:00:00")],
            ["temporal_block", "block_a", "resolution", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_b", "resolution", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_c", "resolution", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_a", "block_end", Dict("type" => "duration", "data" => "1D")],
            ["temporal_block", "block_b", "block_end", Dict("type" => "date_time", "data" => "2000-01-01T15:36:00")],
            ["temporal_block", "block_c", "block_end", nothing],
        ]
        db_api.import_data_to_url(
            url_in; 
            objects=objects,
            relationships=relationships,
            object_parameter_values=object_parameter_values
        )
        using_spinedb(url_in, SpineOpt)
        SpineOpt.generate_temporal_structure()
        @test end_(last(time_slice(temporal_block=temporal_block(:block_a)))) == DateTime("2000-01-02T00:00:00")
        @test end_(last(time_slice(temporal_block=temporal_block(:block_b)))) == DateTime("2000-01-01T15:36:00")
        @test end_(last(time_slice(temporal_block=temporal_block(:block_c)))) == DateTime("2000-01-03T00:00:00")
    end

    @testset "one_two_four_even" begin
        _load_template(url_in)
        db_api.import_data_to_url(url_in; test_data...)
        objects = [["temporal_block", "block_c"]]
        relationships = [["node__temporal_block", ["only_node", "block_c"]]]
        object_parameter_values = [
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2004-01-01T00:00:00")],
            ["temporal_block", "block_a", "resolution", Dict("type" => "duration", "data" => "1Y")],
            ["temporal_block", "block_b", "resolution", Dict("type" => "duration", "data" => "2Y")],
            ["temporal_block", "block_c", "resolution", Dict("type" => "duration", "data" => "4Y")],
        ]
        db_api.import_data_to_url(
            url_in; objects=objects, relationships=relationships, object_parameter_values=object_parameter_values
        )
        using_spinedb(url_in, SpineOpt)
        SpineOpt.generate_temporal_structure()
        observed_ts_a = time_slice(temporal_block=temporal_block(:block_a))
        observed_ts_b = time_slice(temporal_block=temporal_block(:block_b))
        observed_ts_c = time_slice(temporal_block=temporal_block(:block_c))
        expected_ts_a = [TimeSlice(DateTime(i), DateTime(i + 1)) for i in 2000:2003]
        expected_ts_b = [TimeSlice(DateTime(i), DateTime(i + 2)) for i in 2000:2:2003]
        expected_ts_c = [TimeSlice(DateTime(2000), DateTime(2004))]
        @test _is_time_slice_set_equal(observed_ts_a, expected_ts_a)
        @test _is_time_slice_set_equal(observed_ts_b, expected_ts_b)
        @test _is_time_slice_set_equal(observed_ts_c, expected_ts_c)
        a1, a2, a3, a4 = observed_ts_a
        b1, b2 = observed_ts_b
        c1 = observed_ts_c[1]
        expected_t_before_t_a1 = [a2]
        expected_t_before_t_a2 = [a3, b2]
        expected_t_before_t_a3 = [a4]
        expected_t_before_t_a4 = []
        expected_t_before_t_b1 = [a3, b2]
        expected_t_before_t_b2 = []
        expected_t_before_t_c1 = []
        @test _is_time_slice_set_equal(t_before_t(t_before=a1), expected_t_before_t_a1)
        @test _is_time_slice_set_equal(t_before_t(t_before=a2), expected_t_before_t_a2)
        @test _is_time_slice_set_equal(t_before_t(t_before=a3), expected_t_before_t_a3)
        @test _is_time_slice_set_equal(t_before_t(t_before=a4), expected_t_before_t_a4)
        @test _is_time_slice_set_equal(t_before_t(t_before=b1), expected_t_before_t_b1)
        @test _is_time_slice_set_equal(t_before_t(t_before=b2), expected_t_before_t_b2)
        @test _is_time_slice_set_equal(t_before_t(t_before=c1), expected_t_before_t_c1)
        expected_t_in_t_a1 = [a1, b1, c1]
        expected_t_in_t_a2 = [a2, b1, c1]
        expected_t_in_t_a3 = [a3, b2, c1]
        expected_t_in_t_a4 = [a4, b2, c1]
        expected_t_in_t_b1 = [b1, c1]
        expected_t_in_t_b2 = [b2, c1]
        expected_t_in_t_c1 = [c1]
        @test _is_time_slice_set_equal(t_in_t(t_short=a1), expected_t_in_t_a1)
        @test _is_time_slice_set_equal(t_in_t(t_short=a2), expected_t_in_t_a2)
        @test _is_time_slice_set_equal(t_in_t(t_short=a3), expected_t_in_t_a3)
        @test _is_time_slice_set_equal(t_in_t(t_short=a4), expected_t_in_t_a4)
        @test _is_time_slice_set_equal(t_in_t(t_short=b1), expected_t_in_t_b1)
        @test _is_time_slice_set_equal(t_in_t(t_short=b2), expected_t_in_t_b2)
        @test _is_time_slice_set_equal(t_in_t(t_short=c1), expected_t_in_t_c1)
        expected_t_overlaps_t_a1 = [a1, b1, c1]
        expected_t_overlaps_t_a2 = [a2, b1, c1]
        expected_t_overlaps_t_a3 = [a3, b2, c1]
        expected_t_overlaps_t_a4 = [a4, b2, c1]
        expected_t_overlaps_t_b1 = [a1, a2, b1, c1]
        expected_t_overlaps_t_b2 = [a3, a4, b2, c1]
        expected_t_overlaps_t_c1 = [a1, a2, a3, a4, b1, b2, c1]
        @test _is_time_slice_set_equal(t_overlaps_t(a1), expected_t_overlaps_t_a1)
        @test _is_time_slice_set_equal(t_overlaps_t(a2), expected_t_overlaps_t_a2)
        @test _is_time_slice_set_equal(t_overlaps_t(a3), expected_t_overlaps_t_a3)
        @test _is_time_slice_set_equal(t_overlaps_t(a4), expected_t_overlaps_t_a4)
        @test _is_time_slice_set_equal(t_overlaps_t(b1), expected_t_overlaps_t_b1)
        @test _is_time_slice_set_equal(t_overlaps_t(b2), expected_t_overlaps_t_b2)
        @test _is_time_slice_set_equal(t_overlaps_t(c1), expected_t_overlaps_t_c1)
    end
    @testset "two_three_uneven" begin
        _load_template(url_in)
        db_api.import_data_to_url(url_in; test_data...)
        object_parameter_values = [
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2006-01-01T00:00:00")],
            ["temporal_block", "block_a", "resolution", Dict("type" => "duration", "data" => "2Y")],
            ["temporal_block", "block_b", "resolution", Dict("type" => "duration", "data" => "3Y")],
        ]
        db_api.import_data_to_url(url_in; object_parameter_values=object_parameter_values)
        using_spinedb(url_in, SpineOpt)
        SpineOpt.generate_temporal_structure()
        observed_ts_a = time_slice(temporal_block=temporal_block(:block_a))
        observed_ts_b = time_slice(temporal_block=temporal_block(:block_b))
        expected_ts_a = [TimeSlice(DateTime(i), DateTime(i + 2)) for i in 2000:2:2005]
        expected_ts_b = [TimeSlice(DateTime(i), DateTime(i + 3)) for i in 2000:3:2005]
        @test _is_time_slice_set_equal(observed_ts_a, expected_ts_a)
        @test _is_time_slice_set_equal(observed_ts_b, expected_ts_b)
        a1, a2, a3 = observed_ts_a
        b1, b2 = observed_ts_b
        expected_t_before_t_a1 = [a2]
        expected_t_before_t_a2 = [a3]
        expected_t_before_t_a3 = []
        expected_t_before_t_b1 = [b2]
        expected_t_before_t_b2 = []
        @test _is_time_slice_set_equal(t_before_t(t_before=a1), expected_t_before_t_a1)
        @test _is_time_slice_set_equal(t_before_t(t_before=a2), expected_t_before_t_a2)
        @test _is_time_slice_set_equal(t_before_t(t_before=a3), expected_t_before_t_a3)
        @test _is_time_slice_set_equal(t_before_t(t_before=b1), expected_t_before_t_b1)
        @test _is_time_slice_set_equal(t_before_t(t_before=b2), expected_t_before_t_b2)
        expected_t_in_t_a1 = [a1, b1]
        expected_t_in_t_a2 = [a2]
        expected_t_in_t_a3 = [a3, b2]
        expected_t_in_t_b1 = [b1]
        expected_t_in_t_b2 = [b2]
        @test _is_time_slice_set_equal(t_in_t(t_short=a1), expected_t_in_t_a1)
        @test _is_time_slice_set_equal(t_in_t(t_short=a2), expected_t_in_t_a2)
        @test _is_time_slice_set_equal(t_in_t(t_short=a3), expected_t_in_t_a3)
        @test _is_time_slice_set_equal(t_in_t(t_short=b1), expected_t_in_t_b1)
        @test _is_time_slice_set_equal(t_in_t(t_short=b2), expected_t_in_t_b2)
        expected_t_overlaps_t_a1 = [a1, b1]
        expected_t_overlaps_t_a2 = [a2, b1, b2]
        expected_t_overlaps_t_a3 = [a3, b2]
        expected_t_overlaps_t_b1 = [a1, a2, b1]
        expected_t_overlaps_t_b2 = [a2, a3, b2]
        @test _is_time_slice_set_equal(t_overlaps_t(a1), expected_t_overlaps_t_a1)
        @test _is_time_slice_set_equal(t_overlaps_t(a2), expected_t_overlaps_t_a2)
        @test _is_time_slice_set_equal(t_overlaps_t(a3), expected_t_overlaps_t_a3)
        @test _is_time_slice_set_equal(t_overlaps_t(b1), expected_t_overlaps_t_b1)
        @test _is_time_slice_set_equal(t_overlaps_t(b2), expected_t_overlaps_t_b2)
    end
    @testset "gaps" begin
        _load_template(url_in)
        db_api.import_data_to_url(url_in; test_data...)
        objects = [["temporal_block", "block_c"]]
        relationships = [["node__temporal_block", ["only_node", "block_c"]]]
        object_parameter_values = [
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2007-01-11T00:00:00")],
            ["temporal_block", "block_a", "resolution", Dict("type" => "duration", "data" => "1Y")],
            ["temporal_block", "block_b", "resolution", Dict("type" => "duration", "data" => "1Y")],
            ["temporal_block", "block_c", "resolution", Dict("type" => "duration", "data" => "1Y")],
            ["temporal_block", "block_b", "block_start", Dict("type" => "duration", "data" => "4Y")],
            ["temporal_block", "block_c", "block_start", Dict("type" => "duration", "data" => "8Y")],
            ["temporal_block", "block_a", "block_end", Dict("type" => "duration", "data" => "2Y")],
            ["temporal_block", "block_b", "block_end", Dict("type" => "duration", "data" => "6Y")],
            ["temporal_block", "block_c", "block_end", Dict("type" => "duration", "data" => "10Y")],
        ]
        db_api.import_data_to_url(
            url_in; objects=objects, relationships=relationships, object_parameter_values=object_parameter_values
        )
        using_spinedb(url_in, SpineOpt)
        SpineOpt.generate_temporal_structure()
        observed_ts_a = time_slice(temporal_block=temporal_block(:block_a))
        observed_ts_b = time_slice(temporal_block=temporal_block(:block_b))
        observed_ts_c = time_slice(temporal_block=temporal_block(:block_c))
        expected_ts_a = [TimeSlice(DateTime(2000 + i), DateTime(2000 + i + 1)) for i in 0:1]
        expected_ts_b = [TimeSlice(DateTime(2004 + i), DateTime(2004 + i + 1)) for i in 0:1]
        expected_ts_c = [TimeSlice(DateTime(2008 + i), DateTime(2008 + i + 1)) for i in 0:1]
        @test _is_time_slice_set_equal(observed_ts_a, expected_ts_a)
        @test _is_time_slice_set_equal(observed_ts_b, expected_ts_b)
        @test _is_time_slice_set_equal(observed_ts_c, expected_ts_c)
        a1, a2 = observed_ts_a
        b1, b2 = observed_ts_b
        c1, c2 = observed_ts_c
        @test _is_time_slice_set_equal(t_before_t(t_before=a1), [a2])
        @test _is_time_slice_set_equal(t_before_t(t_before=a2), [])
        @test _is_time_slice_set_equal(t_before_t(t_before=b1), [b2])
        @test _is_time_slice_set_equal(t_before_t(t_before=b2), [])
        @test _is_time_slice_set_equal(t_before_t(t_before=c1), [c2])
        @test _is_time_slice_set_equal(t_before_t(t_before=c2), [])
        @test _is_time_slice_set_equal(t_in_t(t_short=a1), [a1])
        @test _is_time_slice_set_equal(t_in_t(t_short=a2), [a2])
        @test _is_time_slice_set_equal(t_in_t(t_short=b1), [b1])
        @test _is_time_slice_set_equal(t_in_t(t_short=b2), [b2])
        @test _is_time_slice_set_equal(t_in_t(t_short=c1), [c1])
        @test _is_time_slice_set_equal(t_in_t(t_short=c2), [c2])
        @test _is_time_slice_set_equal(t_overlaps_t(a1), [a1])
        @test _is_time_slice_set_equal(t_overlaps_t(a2), [a2])
        @test _is_time_slice_set_equal(t_overlaps_t(b1), [b1])
        @test _is_time_slice_set_equal(t_overlaps_t(b2), [b2])
        @test _is_time_slice_set_equal(t_overlaps_t(c1), [c1])
        @test _is_time_slice_set_equal(t_overlaps_t(c2), [c2])
        ab1 = TimeSlice(DateTime(2002), DateTime(2003))
        ab2 = TimeSlice(DateTime(2003), DateTime(2004))
        @test _is_time_slice_equal(SpineOpt.to_time_slice(ab1)[1], a2)
        @test _is_time_slice_equal(SpineOpt.to_time_slice(ab2)[1], a2)
        bc1 = TimeSlice(DateTime(2006), DateTime(2007))
        bc2 = TimeSlice(DateTime(2007), DateTime(2008))
        @test _is_time_slice_equal(SpineOpt.to_time_slice(bc1)[1], b2)
        @test _is_time_slice_equal(SpineOpt.to_time_slice(bc2)[1], b2)
    end
end