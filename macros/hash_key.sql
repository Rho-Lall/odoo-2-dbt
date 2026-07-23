{% macro hash_key(columns) %}
    {#
        Generates a hash key from one or more columns for Data Vault hub and link models.

        Args:
            columns: List of column names or a single column name to hash

        Returns:
            MD5 hash of concatenated column values

        Example:
            {{ hash_key(['company_name', 'cik']) }}
            {{ hash_key('ticker') }}
    #}

    {% if columns is string %}
        {% set column_list = [columns] %}
    {% else %}
        {% set column_list = columns %}
    {% endif %}

    md5(
        concat(
            {% for column in column_list %}
                coalesce(cast({{ column }} as varchar), '')
                {% if not loop.last %}, '||',{% endif %}
            {% endfor %}
        )
    )

{% endmacro %}