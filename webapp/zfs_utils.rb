# Extra methods for parsing and data transformation

class String
    def is_int?
        Integer(self, 10)
        rescue ArgumentError
            false
        else
            true
    end
end


