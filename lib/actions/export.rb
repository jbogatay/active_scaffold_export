module ActiveScaffold::Actions
  module Export
    def self.included(base)
      base.before_filter :export_authorized?, :only => [:export]
      base.before_filter :init_session_var
      
      as_export_plugin_path = File.join(RAILS_ROOT, 'vendor', 'plugins', as_export_plugin_name, 'frontends', 'default', 'views')
      
      if base.respond_to?(:generic_view_paths) && ! base.generic_view_paths.empty?
        base.generic_view_paths.insert(0, as_export_plugin_path)
      else  
        config.inherited_view_paths << as_export_plugin_path
      end
    end    
    
    def self.as_export_plugin_name
      # extract the name of the plugin as installed
      /.+vendor\/plugins\/(.+)\/lib/.match(__FILE__)
      plugin_name = $1
    end
    
    def init_session_var
      session[:search] = params[:search] if !params[:search].nil? || params[:commit] == as_('Search')
      if params[:commit] == as_('Search')
        session[:filters] = params.select {|k,v| k.to_s =~ /filter_/ }
      end
      #session[:filters].merge!(params.select {|k,v| k.to_s =~ /filter_/ })
      logger.debug "ISV    #{params.keys}   Filters = #{session[:filters]}"
    end

    # display the customization form or skip directly to export
    def show_export
      export_config = active_scaffold_config.export
      respond_to do |wants|
        wants.html do
          if successful?
            render(:partial => 'show_export', :layout => true)
          else
            return_to_main
          end
        end
        wants.js do
          render(:partial => 'show_export', :layout => false)
        end
      end
    end

    # if invoked directly, will use default configuration
    def export
      export_config = active_scaffold_config.export
      if params[:export_columns].nil?
        export_columns = {}
        export_config.columns.each { |col|
          export_columns[col.name.to_sym] = 1
        }
        options = {
          :export_columns => export_columns,
          :full_download => export_config.default_full_download.to_s,
          :delimiter => export_config.default_delimiter,
          :skip_header => export_config.default_skip_header.to_s,
          :xls_format => export_config.default_xls_format.to_s
        }
        params.merge!(options)
      end

      find_items_for_export

      response.headers['Content-Disposition'] = "attachment; filename=#{export_file_name}"
      if params[:xls_format]
        render :partial => 'export.rxml', :content_type => 'application/vnd.ms-excel', :status => response_status
      else
        render :partial => 'export', :layout => false, :content_type => Mime::CSV, :status => response_status 
      end
    end

    protected

    # The actual algorithm to do the export
    def find_items_for_export
      export_config = active_scaffold_config.export
      export_columns = export_config.columns.reject { |col| params[:export_columns][col.name.to_sym].nil? }

      includes_for_export_columns = export_columns.collect{ |col| col.includes }.flatten.uniq.compact
      self.active_scaffold_joins.concat includes_for_export_columns
      
      find_options = { :sorting => active_scaffold_config.list.user.sorting }
      params[:search] = session[:search]
      session[:filters].each {|f| params[f.first] = f.last } if session[:filters]

      do_search rescue nil
      params[:segment_id] = session[:segment_id]
      do_segment_search rescue nil
      unless params[:full_download] == 'true'
        find_options.merge!({
          :per_page => active_scaffold_config.list.user.per_page,
          :page => active_scaffold_config.list.user.page
        })
      end
      
      @export_config = export_config
      @export_columns = export_columns
      @records = find_page(find_options).items
    end

    # The default name of the downloaded file.
    # You may override the method to specify your own file name generation.
    def export_file_name
      "#{self.controller_name}.#{params[:xls_format] ? 'xls' : 'csv'}"
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def export_authorized?
      authorized_for?(:action => :read)
    end
  end
end
