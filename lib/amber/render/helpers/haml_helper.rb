require 'pathname'

module HamlHelper

  #
  # acts like haml_tag, capture_haml, or haml_concat, depending on how it is called.
  #
  # two or more args             --> like haml_tag
  # one arg and a block          --> like haml_tag
  # zero args and a block        --> like capture_haml
  # one arg and no block         --> like haml_concat
  #
  # additionally, we allow the use of more than one class.
  #
  # some examples of these usages:
  #
  #   def display_robot(robot)
  #     haml do                                # like capture_haml
  #       haml '.head', robot.head_html        # like haml_tag
  #       haml '.head' do                      # same
  #         haml robot.head_html
  #       end
  #       haml '.body.metal', robot.body_html  # like haml_tag, but with multiple classes
  #       haml '<a href="/x">link</a>'         # like haml_concat
  #     end
  #   end
  #
  # wrapping the helper in a capture_haml call is very useful, because then
  # the helper can be used wherever a normal helper would be.
  #
  def haml(name=nil, *args, &block)
    if name
      if args.empty? and block.nil?
        haml_concat name
      else
        if name =~ /^(.*?\.[^\.]*)(\..*)$/
          # allow chaining of classes if there are multiple '.' in the first arg
          name = $1
          classes = $2.gsub('.',' ')
          hsh = args.detect{|i| i.is_a?(Hash)}
          unless hsh
            hsh = {}
            args << hsh
          end
          hsh[:class] = classes
        end
        haml_tag(name, *args, &block)
      end
    else
      capture_haml(&block)
    end
  end

end