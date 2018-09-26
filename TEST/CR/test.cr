# -- MODULES

module Cibyl

    # -- TYPES

    abstract struct Abstract

    end

    # ~~

    struct Position

        # -- CONSTRUCTORS

        def initialize(
            @x : Int32,
            @y : Int32,
            @z : Int32
            )

        end
    end

    # ~~

    enum Color

        # -- CONSTANTS

        RED
        GREEN
        BLUE

        # -- INQUIRIES

        def is_red?(
            )

            return self == RED;
        end
    end

    # ~~

    struct Point

        # -- CONSTRUCTORS

        def initialize(
            @name : String,
            @position : Position,
            @color : Color
            )

        end

        # -- INQUIRIES

        def is_blue(
            )

            return @color == Color.BLUE;
        end
    end

    # ~~

    struct Person

        # -- ATTRIBUTES

        property name, age, color;

        # -- CONSTRUCTORS

        def initialize(
            @name : String,
            @age : Int32,
            @color : Color
            )

        end

        # -- INQUIRIES

        def is_green?(
            )

            return color == Color.GREEN;
        end

        # -- OPERATIONS

        protected def print(
            )

            puts( "#{age} - #{name}" );
        end
    end

    # ~~

    class Test

        # -- CONSTRUCTORS

        def initialize(
            @hello : String,
            @world : String
            )

        end

        # -- OPERATIONS

        def test_if(
            count : Int
            ) : Int

            if ( count <= 1 )

                return 10;
            end

            if ( count <= 1 )

                return 10;

            else

                return 20;
            end

            if ( count <= 1 )

                return 10;

            elsif ( count <= 2 )

                return 20;

            else

                return 30;
            end
        end

        # ~~

        def test_unless(
            count : Int
            ) : Int

            unless ( count > 1 )

                return 10;
            end

            unless ( count > 1 )

                return 10;

            else

                return 20;
            end
        end

        # ~~

        def test_while(
            count : Int
            )

            index = 0;

            while ( index < count )

                index = index + 1;
            end
        end

        # ~~

        def test_until(
            count : Int
            )

            index = 0;

            until ( index >= count )

                index = index + 1;
            end
        end

        # ~~

        def test_case(
            count : Int
            )

            case ( count )

                when 1

                    return 10;

            end

            case ( count )

                when 1

                    return 10;

                when 2

                    return 20;

            end

            case ( count )

                when 1

                    return 10;

                when 2

                    return 20;

                else

                    return 30;

            end
        end

        # ~~

        def test_begin(
            )

            begin

                result = 1;

            rescue

                result = 2;

            else

                result = 3;

            ensure

                result = 4;
            end
        end

        # ~~

        def test_rescue(
            )

            result = 1;

        rescue

            result = 2;

        else

            result = 3;

        ensure

            result = 4;
        end

        # ~~

        def test_each(
            )

            "0123456789".each_char \
                do |character|

                    print( character );
                end

            print( '\n' );

            [
                {1, "A"},
                {2, "B"}
            ].each \
                do |key, value|

                    puts( "#{@key} : #{@value}" );
                end
        end

        # ~~

        def test_type(
            )

            data = Array( NamedTuple( id: Int32, message: String ) ).new
        end

        # ~~

        def test_interpolation(
            )

            puts( "Test #{@hello + " Test #{@hello} #{@world} Test " + @world} Test" );
            puts( %(Test #{@hello + %( Test #{@hello} #{@world} Test ) + @world} Test) );
            puts( %[Test #{@hello + %[ Test #{@hello} #{@world} Test ] + @world} Test] );
            puts( %{Test #{@hello + %{ Test #{@hello} #{@world} Test } + @world} Test} );
            puts( %<Test #{@hello + %< Test #{@hello} #{@world} Test > + @world} Test> );
            puts( %|Test #{@hello + %| Test #{@hello} #{@world} Test | + @world} Test| );
            puts( %Q(Test #{@hello + %Q( Test #{@hello} #{@world} Test ) + @world} Test) );
            puts( %Q[Test #{@hello + %Q[ Test #{@hello} #{@world} Test ] + @world} Test] );
            puts( %Q{Test #{@hello + %Q{ Test #{@hello} #{@world} Test } + @world} Test} );
            puts( %Q<Test #{@hello + %Q< Test #{@hello} #{@world} Test > + @world} Test> );
            puts( %Q|Test #{@hello + %Q| Test #{@hello} #{@world} Test | + @world} Test| );
            puts( %Q(Test #{@hello + %Q[ Test #{@hello} #{@world} Test ] + @world} Test) );

            puts( "Test \#{@Hello + \" Test #{@hello} #{@world} Test \" + @World} Test" );
            puts( %q(Test #{@Hello + %q( Test #{@Hello} #{@World} Test ) + @World} Test) );
            puts( %q(Test #{@Hello + %q[ Test #{@Hello} #{@World} Test ] + @World} Test) );
        end
    end

    # -- STATEMENTS

    test = Test.new( "Hello", "World" );
    test.test_interpolation();
end

# -- STATEMENTS

require "http/server";

server = HTTP::Server.new \
    do |context|

        context.response.content_type = "text/plain";
        context.response.print( "Hello world! The time is #{Time.now}" );
    end

address = server.bind_tcp( 8080 );
puts( "Listening on http://#{address}" );
server.listen();

