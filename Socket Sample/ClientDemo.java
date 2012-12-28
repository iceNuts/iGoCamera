
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.lang.String;
import java.net.Socket;
import java.net.UnknownHostException;

public class ClientDemo {
	
    /**
     * @param args
     */
    public static void main(String[] args) {
        Socket socket = null;
        try {
            socket = new Socket("192.168.1.107",9875);
            //获取输出流，用于客户端向服务器端发送数据
			DataOutputStream socketOutputStream = new DataOutputStream(socket.getOutputStream());
			byte[] buf = "cossadfsafsds&123\r\n".getBytes("UTF-8");
			socketOutputStream.write(buf,0,buf.length);
			socketOutputStream.flush();
            socket.close();
        } catch (UnknownHostException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
	
}