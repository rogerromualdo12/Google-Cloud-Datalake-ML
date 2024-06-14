
{% macro generate_months_list(start_year, start_month, end_year, end_month) %}
    {% set now = modules.datetime.datetime.now() %}
    {# {% set end_year = now.year %}
    {% set end_month = now.month %} #}

    {% set months = [] %}
    {% for year in range(start_year, end_year + 1) %}
        {% set loop_end_month = 12 if year < end_year else end_month %}
        {% for month in range(1, loop_end_month + 1) %}
            {% if year == start_year and month < start_month %}
                {# Skip months before the start month #}
            {% else %}
                {% set month_string = "{}-{:02}".format(year, month) %}
                {% do months.append(month_string) %}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {{ return(months) }}
{% endmacro %}
