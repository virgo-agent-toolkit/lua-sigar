all:
	cmake -H. -Bbuild
	cmake --build build --config Release

clean:
	rm -rf build
