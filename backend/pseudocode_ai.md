// ── TAHAP 2: VALIDASI RELATIF & EVALUASI PER PARAMETER ──
    UNTUK SETIAP nama_param DALAM ["TSH", "FT4", "FT3", "TRAB"]:
        
        JIKA paramMap TIDAK memiliki nama_param:
            status[nama_param]   = "Tidak Diketahui"
            reminder[nama_param] = "Data tidak tersedia atau tidak valid"
            LANJUT ke parameter berikutnya
        AKHIR JIKA

        p = paramMap[nama_param]

        // Guard Clause Data Kosong
        JIKA p.nilai_hasil == 0 ATAU p.batas_bawah == 0 ATAU p.batas_atas == 0:
            status[nama_param]   = "Tidak Diketahui"
            reminder[nama_param] = "Data tidak lengkap atau tidak valid"
        SELAIN ITU:
            
            // LOGIKA INTERSEPTOR ANTI-TREMOR
            JIKA p.batas_bawah >= p.batas_atas ATAU p.nilai_hasil > (p.batas_atas * 10.0):
                interpretasi = "Perlu Verifikasi Ulang"
                KEMBALIKAN { status[], reminder[], nilai[], interpretasi }
            AKHIR JIKA

            // Klasifikasi Medis Asli
            JIKA nama_param == "TRAB":
                JIKA p.nilai_hasil > p.batas_atas: status[nama_param] = "Positif"
                SELAIN ITU: status[nama_param] = "Negatif"
                AKHIR JIKA
            SELAIN ITU:
                JIKA p.nilai_hasil < p.batas_bawah: status[nama_param] = "Rendah"
                SELAIN JIKA p.nilai_hasil > p.batas_atas: status[nama_param] = "Tinggi"
                SELAIN ITU: status[nama_param] = "Normal"
                AKHIR JIKA
            AKHIR JIKA
        AKHIR JIKA
    AKHIR LOOP