all:
	gcc -c -fPIC -std=c11 -O3 -Wall -Werror -Wextra -Wshadow -Wpointer-arith -Wstrict-prototypes -Wmissing-prototypes -Wold-style-definition -Wvla -o gddr6.o gddr6.c -lpci
	gcc -shared -o gddr6.so gddr6.o
	g++ -o gddr6-prog gddr6-prog.cpp -lgddr6 -lpci
	gcc -std=c11 -O3 -Wall -Werror -Wextra -Wshadow -Wpointer-arith -Wstrict-prototypes -Wmissing-prototypes -Wold-style-definition -Wvla -o gddr6-c-prog gddr6-c-prog.c -lpci
	g++ -o pci-infos pci-infos.cpp -lpci
clean:
	rm -f gddr6.o gddr6.so gddr6-prog gddr6-c-prog pci-infos
install:
	cp gddr6.so /usr/local/lib/libgddr6.so
	ldconfig
	cp gddr6-prog /usr/local/bin/
	cp gddr6-c-prog /usr/local/bin/
	cp pci-infos /usr/local/bin/
