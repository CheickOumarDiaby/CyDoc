require 'fastercsv'

module DiagnosisCodes
  class Base
    include Importer

    def self.path(options = {})
      return options[:input] if options[:input]

      name = "#{self.name.demodulize}.csv"

      case ENV['RAILS_ENV']
        when 'production'
          File.join(RAILS_ROOT, 'data', 'diagnosis_codes', name)
        when 'development', 'test'
          File.join(RAILS_ROOT, 'test', 'fixtures', 'diagnosis_codes', name)
      end
    end

    def self.find(selector, options = {})
      FasterCSV.read(path(options), :col_sep => ';', :headers => false)
    end

    def self.import_all(do_clean = false, options = {})
      ByContractCode.import(do_clean, options)
    end
  end
end
