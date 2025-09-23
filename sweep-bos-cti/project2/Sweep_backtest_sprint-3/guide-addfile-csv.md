bool LoadCSVRowByPreset(const string fname, int presetID, UCRow &out)
{
   int flags = FILE_READ | FILE_CSV | FILE_ANSI; // hoặc FILE_COMMON|FILE_READ|...
   int h = FileOpen(fname, flags);
   if(h==INVALID_HANDLE){
      PrintFormat("FileOpen failed: %s, err=%d", fname, GetLastError());
      return false;
   }

   // đọc header
   string headers[];
   int cols = (int)FileReadStringArray(h, headers); // nếu ông không có helper này, dùng FileReadString từng cột
   // lặp dòng tìm PresetID
   while(!FileIsEnding(h))
   {
      // đọc theo thứ tự cột ông xuất (PresetID, SelectedSymbol, K_swing, ...)
      int    id = (int)FileReadNumber(h);
      string sym = FileReadString(h);
      // ... đọc tiếp đủ cột ...
      // nhớ: FileRead* đúng kiểu dữ liệu

      if(id==presetID){
         out.SelectedSymbol = sym;
         // gán các cột còn lại vào out.*
         FileClose(h);
         return true;
      }
   }
   FileClose(h);
   Print("PresetID not found: ", presetID);
   return false;
}




Phương pháp 2: Ghi Log ra File (Được khuyến nghị)
Để khắc phục nhược điểm của phương pháp 1 và có một bản ghi đầy đủ, bạn cần sửa code EA để ghi tất cả các thông báo quan trọng ra một file text. Đây là cách chuyên nghiệp và hiệu quả nhất.

Thêm các dòng code sau vào EA của bạn (thường là ở phần đầu OnTick() hoặc trong một hàm ghi log chuyên dụng):

mql5
//+------------------------------------------------------------------+
//| Ví dụ hàm ghi log                                                |
//+------------------------------------------------------------------+
void WriteLog(string message)
  {
   string file_name = "MyEA_Optimization_Log.txt"; // Tên file log
   int file_handle = FileOpen(file_name, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON);
   // FILE_COMMON means the file is in the shared folder of all terminals: 
   // \Users\YourUserName\AppData\Roaming\MetaQuotes\Terminal\Common\Files\

   if(file_handle != INVALID_HANDLE)
     {
      FileSeek(file_handle, 0, SEEK_END); // Di chuyển con trỏ đến cuối file để ghi tiếp
      string time = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string text = time + " | Pass: " + (string)OptimizationPass() + " | " + message;
      FileWrite(file_handle, text);
      FileClose(file_handle);
     }
  }
//+------------------------------------------------------------------+
Cách sử dụng hàm trong EA:
Bạn đặt các câu lệnh Print() quan trọng vào các vị trí cần kiểm tra, đồng thời gọi hàm WriteLog().

mql5
void OnTick()
  {
   //... some code ...
   
   if(SomeCondition)
     {
      Print("Điều kiện mua được thỏa mãn"); // Vẫn hiển thị trong Experts
      WriteLog("Điều kiện mua được thỏa mãn"); // Ghi ra file để phân tích sau
     }

   if(GetLastError() != 0)
     {
      Print("Có lỗi xảy ra: ", GetLastError()); // Vẫn hiển thị trong Experts
      WriteLog("Có lỗi xảy ra: " + (string)GetLastError()); // Ghi ra file để phân tích sau
     }
   //... some more code ...
  }