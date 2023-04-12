package logging

import (
	"io"
	"log"
	"os"
	"sync"
)

var logger *log.Logger
var once sync.Once

// Getter for a singleton log.Logger
func GetInstance() *log.Logger {
	once.Do(func() {
		logger = createLogger("../ceremony.log")
	})
	return logger
}

// Creates a new log.Logger
func createLogger(fname string) *log.Logger {
	logFile, err := os.OpenFile(fname, os.O_CREATE|os.O_APPEND|os.O_RDWR, 0666)
	if err != nil {
		log.Fatal(err)
		panic(err)
	}

	logger := log.New(logFile, "", log.Lshortfile|log.LstdFlags)
	mw := io.MultiWriter(os.Stdout, logFile)
	logger.SetOutput(mw)
	return logger
}
