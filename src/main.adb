--
-- Mehdi Ben Djedidia 15/07/2022 --
--
-- Démo du gyroscope mpu-9250
-- et d'un écran oled sh1106
--

with Last_Chance_Handler;
pragma Unreferenced (Last_Chance_Handler);
--  The "last chance handler" is the user-defined routine that is called when
--  an exception is propagated. We need it in the executable, therefore it
--  must be somewhere in the closure of the context clauses.

with STM32.Board; use STM32.Board;
with STM32.Setup;

with Ada.Real_Time; use Ada.Real_Time;

with SH1106; use SH1106; 		-- oled screen (i2c)
with MPU92XX; use MPU92XX; 	-- gyroscope (i2c)

with STM32.Device; use STM32.Device;

with Ravenscar_Time;

with HAL.Bitmap;

with Bitmapped_Drawing;
with BMP_Fonts;
with Interfaces; use Interfaces;

procedure Main is
	Period       : constant Time_Span := Milliseconds (200);
	Next_Release : Time := Clock;

	Oled1106    : SH1106_Screen (Buffer_Size_In_Byte => (128 * 64) / 8,
										Width               => 128,
										Height              => 64,
										Port                => I2C_1'Access,
										RST                 => PA0'Access, -- reset de l'écran ; PA0 choix arbitraire car pas utilisé mais obligatoire
										Time                => Ravenscar_Time.Delays);

	Gyro : MPU92XX_Device (Port        => I2C_2'Access,
								I2C_AD0_Pin => Low, 	-- Pin ADO ici sur GND (Low) : Low/High to change I2C address
								Time        => Ravenscar_Time.Delays);

	-- valeurs lues sur le MPU92XX
	Acc_X, Acc_Y, Acc_Z    : Integer_16;
	Gyro_X, Gyro_Y, Gyro_Z : Integer_16;

	Angle_X, Angle_Y       : Float;

	Degre                  : constant := 180.0 / 3.1415; -- pour la conversion de rd en degré

begin

	-- initialiser la led utilisateur verte
	STM32.Board.Initialize_LEDs;
	STM32.Board.Turn_On (Green_LED);

	-- initialisation du port I2C 1 pour l'écran oled sh1106 en i2c
	STM32.Setup.Setup_I2C_Master  (Port        => I2C_1,
										  SDA         => PB9,
										  SCL         => PB8,
										  SDA_AF      => GPIO_AF_I2C1_4,
										  SCL_AF      => GPIO_AF_I2C1_4,
										  Clock_Speed => 100_000); -- 100 KHz

	-- initialisation de l'oled sh1106
	Oled1106.Initialize;
	Oled1106.Initialize_Layer;
	Oled1106.Turn_On;

	-- clear screen
	Oled1106.Hidden_Buffer.Set_Source (HAL.Bitmap.Black);
	Oled1106.Hidden_Buffer.Fill;

	-- initialisation du port I2C 2 pour l'accès au MPU92XX en i2c
	STM32.Setup.Setup_I2C_Master  (Port        => I2C_2,
										  SDA         => PB3,
										  SCL         => PB10,
										  SDA_AF      => GPIO_AF_I2C2_4,
										  SCL_AF      => GPIO_AF_I2C2_4,
										  Clock_Speed => 400_000); -- Le MPU9250 peut échanger à 400 KHz

	-- initialisation du MPU92XX

	MPU92XX_Init (Device => Gyro);

	-- enable the temperature sensor
	MPU92XX_Set_Temp_Sensor_Enabled (Device => Gyro,
											 Value  => True);

	-- test
	if MPU92XX_Test (Device => Gyro) then
		Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
											Start      => (0, 0),
											Msg        => "DEVICE OK",
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);
	else
		Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
											Start      => (0, 0),
											Msg        => "DEVICE KO",
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.Black,
											Background => HAL.Bitmap.White);
	end if;


	-- afficher l'id du device
	Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
										  Start      => (0, 10),
										  Msg        => "ID " & MPU92XX_Who_Am_I (Gyro)'Img,
										  Font       => BMP_Fonts.Font8x8,
										  Foreground => HAL.Bitmap.White,
										  Background => HAL.Bitmap.Black);

	Oled1106.Update_Layer;


	STM32.Board.Turn_Off (Green_LED);

	loop
		STM32.Board.Toggle (Green_LED);


		-- effacer la zone des coordonnées avant un nouvel affichage
		Oled1106.Hidden_Buffer.Set_Source (HAL.Bitmap.Black);
		Oled1106.Hidden_Buffer.Fill_Rect (Area => (Position => (0, 20),
															Width    => 128,
															Height   => 40));

		MPU92XX_Get_Motion_6 (Device => Gyro,
								Acc_X  => Acc_X,
								Acc_Y  => Acc_Y,
								Acc_Z  => Acc_Z,
								Gyro_X => Gyro_X,
								Gyro_Y => Gyro_Y,
								Gyro_Z => Gyro_Z);

		Compute_Angles (Acc_X   => Float (Acc_X),
						Acc_Y   => Float (Acc_Y),
						Acc_Z   => Float (Acc_Z),
						Angle_X => Angle_X,
						Angle_Y => Angle_Y);

		-- conversion en degrés
		Angle_X := @ * Degre;
		Angle_Y := @ * Degre;

		Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
											Start      => (0, 20),
											Msg        =>	 "X" & Angle_X'Image,
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);

		Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
											Start      => (0, 30),
											Msg        => "Y" & Angle_Y'Image,
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);



		--  Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
		--  									Start      => (0, 20),
		--  									Msg        => Acc_X'Image,
		--  									Font       => BMP_Fonts.Font8x8,
		--  									Foreground => HAL.Bitmap.White,
		--  									Background => HAL.Bitmap.Black);
		--  Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
		--  									Start      => (0, 30),
		--  									Msg        => Acc_Y'Image,
		--  									Font       => BMP_Fonts.Font8x8,
		--  									Foreground => HAL.Bitmap.White,
		--  									Background => HAL.Bitmap.Black);
		--  Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
		--  									Start      => (0, 40),
		--  									Msg        => Acc_Z'Image,
		--  									Font       => BMP_Fonts.Font8x8,
		--  									Foreground => HAL.Bitmap.White,
		--  									Background => HAL.Bitmap.Black);
		--
		--  Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
		--  									Start      => (50, 20),
		--  									Msg        => Gyro_X'Image,
		--  									Font       => BMP_Fonts.Font8x8,
		--  									Foreground => HAL.Bitmap.White,
		--  									Background => HAL.Bitmap.Black);
		--  Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
		--  									Start      => (50, 30),
		--  									Msg        => Gyro_Y'Image,
		--  									Font       => BMP_Fonts.Font8x8,
		--  									Foreground => HAL.Bitmap.White,
		--  									Background => HAL.Bitmap.Black);
		--  Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
		--  									Start      => (50, 40),
		--  									Msg        => Gyro_Z'Image,
		--  									Font       => BMP_Fonts.Font8x8,
		--  									Foreground => HAL.Bitmap.White,
		--  									Background => HAL.Bitmap.Black);

		-- afficher la température
		Bitmapped_Drawing.Draw_String (Oled1106.Hidden_Buffer.all,
											Start      => (0, 50),
											Msg        => "TEMP" & MPU92XX_Get_Temperature (Gyro)'Img,
											Font       => BMP_Fonts.Font8x8,
											Foreground => HAL.Bitmap.White,
											Background => HAL.Bitmap.Black);



		-- mise à jour de l'affichage
		Oled1106.Update_Layer;

		Next_Release := Next_Release + Period;
		delay until Next_Release;
	end loop;
end Main;
