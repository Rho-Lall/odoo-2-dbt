{% macro hash_diff(columns, exclude_columns=[]) %}
    {#
        Generates a hash diff from descriptive columns for Data Vault satellite models.
        Used for change detection - when hash_diff changes, a new satellite record is created.

        Args:
            columns: List of all descriptive column names to include in hash
            exclude_columns: Optional list of columns to exclude from hash (e.g., metadata fields)

        Returns:
            MD5 hash of concatenated descriptive attribute values

        Example:
            {{ hash_diff(['company_name', 'industry', 'sector'], exclude_columns=['load_datetime']) }}
    #}

    {% set included_columns = [] %}
    {% for column in columns %}
        {% if column not in exclude_columns %}
            {% do included_columns.append(column) %}
        {% endif %}
    {% endfor %}

    md5(
        concat(
            {% for column in included_columns %}
                coalesce(cast({{ column }} as varchar), '')
                {% if not loop.last %}, '||',{% endif %}
            {% endfor %}
        )
    )

{% endmacro %}