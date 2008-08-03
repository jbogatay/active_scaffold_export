module ActiveScaffold
  module Helpers
    # Helpers that assist with the rendering of a Export Column
    module ExportHelpers
      ## individual columns can be overridden by defining
      # a helper method <column_name>_export_column(record)
      # You can customize the output of all columns by
      # overriding the following helper methods:
      # format_export_column(raw_value)
      # format_singular_association_export_column(association_record)
      # format_plural_association_export_column(association_records)
      def get_export_column_value(record, column)
        if export_column_override? column
          send(export_column_override(column), record)
        else
          raw_value = record.send(column.name)

          if column.association.nil? or column_empty?(raw_value)
            format_export_column(raw_value)
          else
            case column.association.macro
            when :has_one, :belongs_to
              format_singular_association_export_column(raw_value)
            when :has_many, :has_and_belongs_to_many
              format_plural_association_export_column(raw_value)
            end
          end
        end
      end

      def export_column_override(column)
        "#{column.name.to_s.gsub('?', '')}_export_column" # parse out any question marks (see issue 227)
      end

      def export_column_override?(column)
        respond_to?(export_column_override(column))
      end

      def format_export_column(raw_value)
        format_column(raw_value)
      end

      def format_singular_association_export_column(association_record)
        format_column(association_record.to_label)
      end

      def format_plural_association_export_column(association_records)
        firsts = association_records.first(4).collect { |v| v.to_label }
        firsts[3] = '�' if firsts.length == 4
        format_column(firsts.join(','))
      end

      ## This helper can be overridden to change the way that the headers
      # are formatted. For instance, you might want column.name.to_s.humanize
      def format_export_column_header_name(column)
        column.name.to_s.humanize
        #column.name.to_s
      end
      
      def format_export_column(column_value)
        if column_empty?(column_value)
          active_scaffold_config.list.empty_field_text
        elsif column_value.instance_of? Time
          format_export_time(column_value)
        elsif column_value.instance_of? Date
          format_export_date(column_value)
        else
          column_value.to_s
        end
      end

      def format_export_time(time)
        #format = ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS[:default] || "%m/%d/%Y %I:%M %p"
        format = '%Y-%m-%d %H:%M:%S'
        time.strftime(format)
      end

      def format_export_date(date)
        #format = ActiveSupport::CoreExtensions::Date::Conversions::DATE_FORMATS[:default] || "%m/%d/%Y"
        format = '%Y-%m-%d'
        date.strftime(format)
      end
      
    end
  end
end
