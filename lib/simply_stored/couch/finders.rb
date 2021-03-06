module SimplyStored
  module Couch
    module Finders
      def find(*args)
        what = args.shift

        eager_load_params = nil
        args.each do |arg| 
          if arg[:eager_load]
            eager_load_params = args.delete(arg)
          end
        end

        options = args.last.is_a?(Hash) ? args.last : {}
        if options && order = options.delete(:order)
          options[:descending] = true if order == :desc
        end

        with_deleted = options.delete(:with_deleted)
        
        pagination_params = 
        if ancestors.include? SimplyStored::Couch::Paginator
          build_pagination_params
        else
          {}
        end

        case what
        when :all
          if with_deleted || !soft_deleting_enabled?
            results = CouchPotato.database.view(all_documents(*args, pagination_params))

            if eager_load_params
              SimplyStored::Couch::Helper.eager_load(results, eager_load_params[:eager_load])
            end

            unless pagination_params.empty?
              SimplyStored::Couch::Helper.paginate(results, pagination_params) # Converts results into will_paginate array
            else
              results
            end
          else
            results = CouchPotato.database.view(all_documents_without_deleted(options.update(:include_docs => true).merge(pagination_params)))
            
            SimplyStored::Couch::Helper.eager_load(results, eager_load_params[:eager_load]) if eager_load_params

            unless pagination_params.empty?
              SimplyStored::Couch::Helper.paginate(results, pagination_params)
            else
              results
            end
          end
        when :first
          if with_deleted || !soft_deleting_enabled?
            CouchPotato.database.view(all_documents(:limit => 1, :include_docs => true)).first
          else
            CouchPotato.database.view(all_documents_without_deleted(:limit => 1, :include_docs => true)).first
          end
        else          
          raise SimplyStored::Error, "Can't load record without an id" if what.nil?
          document = CouchPotato.database.load_document(what)
          if document.nil? or !document.is_a?(self) or (document.deleted? && !with_deleted)
            raise(SimplyStored::RecordNotFound, "#{self.name} could not be found with #{what.inspect}")
          end
          document
        end
      end
      
      def all(*args)
        find(:all, *args)
      end
      
      def first(*args)
        find(:first, *args)
      end

      def last(*args)
        find(:first, {:order => :desc}, *args)
      end

      def count(options = {})
        options.assert_valid_keys(:with_deleted)
        with_deleted = options[:with_deleted]
        
        if with_deleted || !soft_deleting_enabled?
          CouchPotato.database.view(all_documents(:reduce => true))
        else
          CouchPotato.database.view(all_documents_without_deleted(:reduce => true))
        end
      end
    end
  end
end