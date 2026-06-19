package command

import (
	"log"

	"github.com/spf13/cobra"

	application "monitoring-service/app"
)

func init() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds | log.Llongfile)
}

var cmdRoot = &cobra.Command{
	Use:   "master-service",
	Short: "The master-service is a service to handle the visee.id project master domain.",
	Long:  `The master-service is a service to handle the requirements of the master-service`,
	Run: func(cmd *cobra.Command, args []string) {
        app := application.New()
        err := app.Init()
        if err != nil {
            // Kita log saja, jangan fatal supaya aplikasi lanjut ke tahap berikutnya
            log.Printf("Peringatan saat inisialisasi: %+v", err)
        }

        err = app.Run()
        if err != nil {
            log.Fatalf("Error saat aplikasi berjalan: %+v", err)
        }
    },
}

func Execute() {
	if err := cmdRoot.Execute(); err != nil {
		log.Fatalf("Error in executing the root command: %+v", err)
	}
}
