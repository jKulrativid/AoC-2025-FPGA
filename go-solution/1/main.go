package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
)

const FileToUse = "input.txt"

//const FileToUse = "testcase.txt"

func parseRawInstruction(rawInst string) (byte, int) {
	if len(rawInst) < 2 {
		panic("lenght must be greater than 2")
	}

	rotation := rawInst[0]
	if rotation != 'L' && rotation != 'R' {
		panic("direction must be L or R")
	}

	rawDistance := rawInst[1:]
	distance, err := strconv.Atoi(rawDistance)
	if err != nil {
		panic(fmt.Errorf("failed to convert raw distance string (%s) into integer: %w", rawDistance, err))
	}

	return rotation, distance
}

func firstPart() int {
	current := 50

	totalZero := 0

	inputFile, err := os.Open(FileToUse)
	if err != nil {
		panic(fmt.Errorf("failed to open %s: %w", FileToUse, err))
	}
	defer inputFile.Close()

	fileScanner := bufio.NewScanner(inputFile)
	// INFO: if the input file contians line larger than 64kB
	// consider increasing scanner's buffer with '.Buffer'

	for fileScanner.Scan() {
		rawInst := fileScanner.Text()

		rotation, distance := parseRawInstruction(rawInst)

		switch rotation {
		case 'L':
			distance = 100 - distance // L37 is basicaly R(100-37), i.e. R63
		case 'R':
			// DO NOTHING
		default:
			panic(fmt.Errorf("unknown rotation (%s)", string(rotation)))
		}

		current = (current + distance) % 100

		if current == 0 {
			totalZero += 1
		}
	}

	return totalZero
}

func secondPart() int {
	current := 50

	zeroHitsCount := 0

	inputFile, err := os.Open(FileToUse)
	if err != nil {
		panic(fmt.Errorf("failed to open %s: %w", FileToUse, err))
	}
	defer inputFile.Close()

	fileScanner := bufio.NewScanner(inputFile)
	// INFO: if the input file contians line larger than 64kB
	// consider increasing scanner's buffer with '.Buffer'

	convertCurrentRelativity := func(current int, rotation byte) int {
		if current == 0 {
			// prevent returning 100 in case or rotation=L and current=0
			return 0
		}

		switch rotation {
		case 'L':
			return 100 - current
		case 'R':
			return current
		default:
			panic(fmt.Errorf("unknown rotation (%s)", string(rotation)))
		}
	}

	for fileScanner.Scan() {
		rawInst := fileScanner.Text()

		rotation, distance := parseRawInstruction(rawInst)

		relativeCurrent := convertCurrentRelativity(current, rotation)

		zeroHitsCount += (relativeCurrent + distance) / 100
		relativeCurrent = (relativeCurrent + distance) % 100

		current = convertCurrentRelativity(relativeCurrent, rotation)
	}

	return zeroHitsCount
}

func main() {
	fmt.Println("first part", firstPart())
	fmt.Println("second part", secondPart())
}
