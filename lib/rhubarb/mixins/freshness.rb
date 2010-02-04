# Freshness-based queries ("find_freshest") for Rhubarb classes.
#
# Copyright (c) 2009--2010 Red Hat, Inc.
#
# Author:  William Benton (willb@redhat.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0

module Rhubarb
  module FindFreshest
    # args contains the following keys
    #  * :group_by maps to a list of columns to group by (mandatory)
    #  * :select_by maps to a hash mapping from column symbols to values (optional)
    #  * :version maps to some version to be considered "current" for the purposes of this query; that is, all rows later than the "current" version will be disregarded (optional, defaults to latest version)
    def find_freshest(args)
      args = args.dup

      args[:version] ||= Util::timestamp
      args[:select_by] ||= {}

      query_params = {}
      query_params[:version] = args[:version]

      select_clauses = ["created <= :version"]

      valid_cols = self.colnames.intersection args[:select_by].keys

      valid_cols.map do |col|
        select_clauses << "#{col.to_s} = #{col.inspect}"
        val = args[:select_by][col]
        val = val.row_id if val.respond_to? :row_id
        query_params[col] = val
      end

      group_by_clause = "GROUP BY " + args[:group_by].join(", ")
      where_clause = "WHERE " + select_clauses.join(" AND ")
      projection = self.colnames - [:created]
      join_clause = projection.map do |column|
        "__fresh.#{column} = __freshest.#{column}"
      end

      projection << "MAX(created) AS __current_version"
      join_clause << "__fresh.__current_version = __freshest.created"

      query = "
  SELECT __freshest.* FROM (
    SELECT #{projection.to_a.join(', ')} FROM (
      SELECT * from #{table_name} #{where_clause}
    ) #{group_by_clause}
  ) as __fresh INNER JOIN #{table_name} as __freshest ON
    #{join_clause.join(' AND ')}
    ORDER BY row_id
  "

      self.db.execute(query, query_params).map {|tup| self.new(tup) }
    end
  end
end