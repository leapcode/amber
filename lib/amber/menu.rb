#
# A navigation menu class
#

module Amber
  class Menu
    attr_accessor :parent
    attr_accessor :children
    attr_accessor :name

    #
    # load the menu.txt file and build the in-memory menu array
    #
    def load(menu_file_path)
      File.open(menu_file_path) do |file|
        parse_menu(file)
      end
    end

    def initialize(name, parent=nil)
      self.name = name
      self.parent = parent
      self.children = []
    end

    ##
    ## public methods
    ##

    #
    # returns the menu under the item that matches item_name.
    #
    def submenu(item_name=nil)
      if item_name
        self.children.detect {|child| child.name == item_name}
      else
        self.children
      end
    end

    #
    # returns path from root to this leaf as an array
    #
    def path
      @path ||= begin
        if parent == nil
          []
        else
          parent.path + [name]
        end
      end
    end

    def path_str
      @path_str ||= path.join('/')
    end

    def each(&block)
      children.each(&block)
    end

    def size
      children.size
    end

    #
    # returns true if menu's path starts with +path_prefix+
    #
    def path_starts_with?(path_prefix)
      array_starts_with?(path, path_prefix)
    end

    def path_prefix_of?(full_path)
      array_starts_with?(full_path, path)
    end

    #
    # returns true if this menu item is the terminus menu item for path.
    # (meaning that there are no children that match more path segments)
    #
    def leaf_for_path?(path)
      return false unless path_prefix_of?(path)
      next_path_segment = (path - self.path).first
      return false if next_path_segment.nil?
      return !children.detect {|i| i.name == next_path_segment}
    end

    def inspect(indent=0)
      lines = []
      lines << '  '*indent + '- ' + self.name
      self.children.each do |child|
        lines << child.inspect(indent+1)
      end
      lines.join("\n")
    end

    #
    # private & protected methods
    #

    protected

    def add_child(name)
      self.children << Menu.new(name, self)
    end

    private

    def array_starts_with?(big_array, small_array)
      small_array.length.times do |i|
        if small_array[i] != big_array[i]
          return false
        end
      end
      return true
    end


    def parse_menu(file)
      while true
        item = file.readline
        if item.strip.chars.any? && item !~ /^\s*#/
          depth = item.scan("  ").size
          last_menu_at_depth(depth).add_child(item.strip)
        end
      end
    rescue EOFError
      # done loading
    end

    #
    # returns the last list of children at the specified depth
    #
    def last_menu_at_depth(depth)
      menu = self
      depth.times { menu = menu.children.last }
      menu
    end

  end
end