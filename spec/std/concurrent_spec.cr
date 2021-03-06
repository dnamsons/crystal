require "./spec_helper"

private def method_with_named_args(chan, x = 1, y = 2)
  chan.send(x + y)
end

private def method_named(expected_named, chan)
  Fiber.current.name.should eq(expected_named)
  chan.close
end

class SomeParallelJobException < Exception
end

private def raising_job : String
  raise SomeParallelJobException.new("boom")
  "result"
end

describe "concurrent" do
  describe "parallel" do
    pending_win32 "does four things concurrently" do
      a, b, c, d = parallel(1 + 2, "hello".size, [1, 2, 3, 4].size, nil)
      a.should eq(3)
      b.should eq(5)
      c.should eq(4)
      d.should be_nil
    end

    pending_win32 "re-raises errors from Fibers as ConcurrentExecutionException" do
      exception = expect_raises(ConcurrentExecutionException) do
        a, b = parallel(raising_job, raising_job)
      end

      exception.cause.should be_a(SomeParallelJobException)
    end

    # FIXME: Compiler bug with typeof inside an unused block https://github.com/crystal-lang/crystal/issues/8669
    {% unless flag?(:win32) %}
      pending_win32 "is strict about the return value type" do
        a, b = parallel(1 + 2, "hello")

        typeof(a).should eq(Int32)
        typeof(b).should eq(String)
      end
    {% end %}
  end

  describe "spawn" do
    it "uses spawn macro" do
      chan = Channel(Int32).new

      spawn method_with_named_args(chan)
      chan.receive.should eq(3)

      spawn method_with_named_args(chan, y: 20)
      chan.receive.should eq(21)

      spawn method_with_named_args(chan, x: 10, y: 20)
      chan.receive.should eq(30)
    end

    it "spawns named" do
      chan = Channel(Nil).new
      spawn(name: "sub") do
        Fiber.current.name.should eq("sub")
        chan.close
      end
      chan.receive?
    end

    it "spawns named with macro" do
      chan = Channel(Nil).new
      spawn method_named("foo", chan), name: "foo"
      chan.receive?
    end
  end

  it "accepts method call with receiver" do
    typeof(spawn String.new)
  end
end
