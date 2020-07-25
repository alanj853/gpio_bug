defmodule Reader do
    use GenServer
    alias Circuits.GPIO

    @read_gpio_rate 1_000
    @read_mem_rate 180_000
    @output_file "./erl_mem_usage.csv"

    @pin0 1
    @pin1 2

    def start_link(args \\ nil) do
        GenServer.start_link(__MODULE__, args, name: __MODULE__)
    end

    def stop_read() do
        GenServer.cast(__MODULE__, :stop_read)
    end

    def start_read() do
        GenServer.cast(__MODULE__, :start_read)
    end

    def init(_) do
        File.rename(@output_file, @output_file <> ".1")
        File.touch(@output_file)
        {:ok, io_device} =
        File.open(@output_file, [:write, :append], fn file ->
            IO.write(
            file,
            "Total,Processes,ProcessesUsed,System,Atom,AtomUsed,Binary,Code,ETS"
            )
            IO.write(file, "\n")
        end)
        File.close(io_device)
        
        :timer.send_interval(@read_mem_rate, :read_mem)
        :timer.send_interval(@read_gpio_rate, :read_gpio)
        {:ok, %{can_read: true}}
    end

    def handle_cast(:stop_read, _state) do
        {:ok, io_device} =
        File.open(@output_file, [:write, :append], fn file ->
            IO.write(file, "GPIO Reading stopped\n")
        end)
        File.close(io_device)
        {:noreply, %{can_read: false}}
    end

    def handle_cast(:start_read, _state) do
        {:ok, io_device} =
        File.open(@output_file, [:write, :append], fn file ->
            IO.write(file, "GPIO Reading started\n")
        end)
        File.close(io_device)
        {:noreply, %{can_read: true}}
    end

    def handle_info(:read_gpio, state = %{can_read: true}) do
        read_pins()
        {:noreply, state}
    end

    def handle_info(:read_gpio, state = %{can_read: false}) do
        {:noreply, state}
    end

    def handle_info(:read_mem, state) do
        read_mem()
        {:noreply, state}
    end

    def read_mem() do
        {:ok, io_device} =
        File.open(@output_file, [:write, :append], fn file ->
            for {_key, val} <- :erlang.memory() do
                IO.write(file, "#{val},")
            end
            IO.write(file, "\n")
        end)
        File.close(io_device)
    end

    def read_pins() do
        {_, pin0_pid} = GPIO.open(@pin0, :input)
        {_, pin1_pid} = GPIO.open(@pin1, :input)
    
        GPIO.read(pin0_pid)
        GPIO.read(pin1_pid)

        GPIO.close(pin0_pid)
        GPIO.close(pin1_pid)
    end

end

